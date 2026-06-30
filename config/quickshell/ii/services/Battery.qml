pragma Singleton

import qs.services
import qs.modules.common
import Quickshell
import Quickshell.Services.UPower
import QtQuick
import Quickshell.Io

Singleton {
    id: root
    property bool available: UPower.displayDevice.isLaptopBattery
    property var chargeState: UPower.displayDevice.state
    property bool isCharging: chargeState == UPowerDeviceState.Charging
    // AC connected = NOT on battery. Robust at 100% (state is "fully charged", not
    // "charging") — UPower.onBattery is the canonical, reactive flag.
    property bool isPluggedIn: !UPower.onBattery
    property real percentage: UPower.displayDevice?.percentage ?? 1
    readonly property bool allowAutomaticSuspend: Config.options.battery.automaticSuspend
    readonly property bool soundEnabled: Config.options.sounds.battery

    property bool isLow: available && (percentage <= Config.options.battery.low / 100)
    property bool isCritical: available && (percentage <= Config.options.battery.critical / 100)
    property bool isSuspending: available && (percentage <= Config.options.battery.suspend / 100)
    property bool isFull: available && (percentage >= Config.options.battery.full / 100)

    property bool isLowAndNotCharging: isLow && !isCharging
    property bool isCriticalAndNotCharging: isCritical && !isCharging
    property bool isSuspendingAndNotCharging: allowAutomaticSuspend && isSuspending && !isCharging
    property bool isFullAndCharging: isFull && isCharging

    property real energyRate: UPower.displayDevice.changeRate
    property real timeToEmpty: UPower.displayDevice.timeToEmpty
    property real timeToFull: UPower.displayDevice.timeToFull

    property real health: {
        const dev = UPower.displayDevice
        if (dev && dev.isLaptopBattery && dev.healthSupported)
            return dev.healthPercentage
        // ponytail: UPower energy ratio fallback — same source, always reactive
        if (energyFullDesign > 0) return energyFull / energyFullDesign * 100
        return -1
    }


    onIsLowAndNotChargingChanged: {
        if (!root.available || !isLowAndNotCharging) return;
        Quickshell.execDetached([
            "notify-send", 
            Translation.tr("Low battery"), 
            Translation.tr("Consider plugging in your device"), 
            "-u", "critical",
            "-a", "Shell",
            "--hint=int:transient:1",
        ])

        if (root.soundEnabled) Audio.playSystemSound("dialog-warning");
    }

    onIsCriticalAndNotChargingChanged: {
        if (!root.available || !isCriticalAndNotCharging) return;
        Quickshell.execDetached([
            "notify-send", 
            Translation.tr("Critically low battery"), 
            Translation.tr("Please charge!\nAutomatic suspend triggers at %1%").arg(Config.options.battery.suspend), 
            "-u", "critical",
            "-a", "Shell",
            "--hint=int:transient:1",
        ]);

        if (root.soundEnabled) Audio.playSystemSound("suspend-error");
    }

    onIsSuspendingAndNotChargingChanged: {
        if (root.available && isSuspendingAndNotCharging) {
            Quickshell.execDetached(["bash", "-c", `systemctl suspend || loginctl suspend`]);
        }
    }

    onIsFullAndChargingChanged: {
        if (!root.available || !isFullAndCharging) return;
        Quickshell.execDetached([
            "notify-send",
            Translation.tr("Battery full"),
            Translation.tr("Please unplug the charger"),
            "-a", "Shell",
            "--hint=int:transient:1",
        ]);

        if (root.soundEnabled) Audio.playSystemSound("complete");
    }

    onIsPluggedInChanged: {
        // Only the tracker process touches the persisted clocks, and only on a
        // GENUINE plug/unplug edge. We compare against the baseline that
        // reconcileUsage() recorded, so the startup UPower settle (default false →
        // real value) is never misread as an unplug regardless of signal ordering.
        if (!root.isTracker || !root.usageReady) return;
        if (root.isPluggedIn === root._lastPlugged) return;
        root._lastPlugged = root.isPluggedIn;
        if (root.isPluggedIn) {
            root.onBatterySince = 0;
        } else {
            root.onBatterySince = root.nowSec();
            root.screenOnSeconds = 0;
            root.lastTick = root.nowSec();
        }
        root.persistUsage();
        // Sounds
        if (!root.available || !root.soundEnabled) return;
        Audio.playSystemSound(isPluggedIn ? "power-plug" : "power-unplug");
    }

    onIsFullChanged: if (isFull && root.isTracker) { root.lastFullTime = root.nowSec(); root.persistUsage(); }

    // --- Hardware extras (UPower doesn't expose all) -------------------------
    property int cycleCount: 0
    property real voltage: 0       // volts
    property string technology: ""
    property real energyNow: 0     // Wh
    property real energyFull: 0    // Wh
    property real energyFullDesign: 0

    Process {
        id: sysReadProc
        running: true
        command: ["bash", "-c",
            'b=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1); [ -z "$b" ] && exit 0; ' +
            'echo "cycle:$(cat $b/cycle_count 2>/dev/null)"; ' +
            'echo "volt:$(cat $b/voltage_now 2>/dev/null)"; ' +
            'echo "tech:$(cat $b/technology 2>/dev/null)"; ' +
            'echo "enow:$(cat $b/energy_now 2>/dev/null)"; ' +
            'echo "efull:$(cat $b/energy_full 2>/dev/null)"; ' +
            'echo "edesign:$(cat $b/energy_full_design 2>/dev/null)"'
        ]
        stdout: SplitParser {
            onRead: line => {
                const i = line.indexOf(":"); if (i < 0) return;
                const k = line.slice(0, i), v = line.slice(i + 1).trim();
                if (k === "cycle") root.cycleCount = parseInt(v) || 0;
                else if (k === "volt") root.voltage = (parseInt(v) || 0) / 1e6;
                else if (k === "tech") root.technology = v;
                else if (k === "enow") root.energyNow = (parseInt(v) || 0) / 1e6;
                else if (k === "efull") root.energyFull = (parseInt(v) || 0) / 1e6;
                else if (k === "edesign") root.energyFullDesign = (parseInt(v) || 0) / 1e6;
            }
        }
    }
    Timer { interval: 30000; running: true; repeat: true; onTriggered: sysReadProc.running = true }

    // --- Battery % history (persistent, 15-min samples, 2-yr window) ----------
    // Format: [[timestamp_sec, percent_0_to_100], ...]  — tracker writes, readers reload.
    property var batteryHistory: []

    // Sample format: [timestamp, percent, watts, "proc:cpu%,...", rx_bytes, tx_bytes]
    // watts/procs/rx/tx are "" / 0 for UPower-seeded entries
    property string _pendingProcs: ""
    property real _pendingRx: 0
    property real _pendingTx: 0

    // Capture top 5 procs + wattage + net bytes, then write sample
    Process {
        id: topProcSampler
        command: ["bash", "-c",
            "p=$(ps -eo comm,%cpu --sort=-%cpu --no-headers | " +
            "awk '$2>0.3 && NR<=5 {printf \"%s:%.1f,\",$1,$2}' | sed 's/,$//'); " +
            "n=$(awk 'NR>2 && $1!=\"lo:\"{rx+=$2;tx+=$10}END{print rx\" \"tx}' /proc/net/dev); " +
            "echo \"$p|$n\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const pipe = text.indexOf("|")
                root._pendingProcs = (pipe >= 0 ? text.slice(0, pipe) : text).trim()
                const parts = (pipe >= 0 ? text.slice(pipe + 1) : "").trim().split(" ")
                root._pendingRx = parseInt(parts[0]) || 0
                root._pendingTx = parseInt(parts[1]) || 0
            }
        }
        onExited: {
            if (!root.isTracker) return
            const now = root.nowSec()
            const cutoff = now - 2 * 365 * 86400
            const h = root.batteryHistory.filter(s => s[0] >= cutoff)
            h.push([now, Math.round(root.percentage * 100),
                    parseFloat(Math.abs(root.energyRate).toFixed(2)),
                    root._pendingProcs,
                    root._pendingRx,
                    root._pendingTx])
            root.batteryHistory = h
            historyFile.setText(JSON.stringify({ samples: h }))
        }
    }
    Timer {
        interval: 900000  // 15 min
        running: root.isTracker
        repeat: true
        triggeredOnStart: true
        onTriggered: topProcSampler.running = true
    }
    Timer {
        // Non-tracker instances reload the history every 15 min to stay in sync.
        interval: 900000; running: !root.isTracker; repeat: true; triggeredOnStart: false
        onTriggered: historyFile.reload()
    }
    FileView {
        id: historyFile
        path: Qt.resolvedUrl(`${Directories.state}/user/battery_history.json`)
        onLoaded: {
            try { root.batteryHistory = JSON.parse(historyFile.text()).samples ?? [] } catch (e) {}
            // Seed if we have no data older than 1 day (fresh install or new file)
            const hasHistory = root.batteryHistory.some(s => s[0] < root.nowSec() - 86400)
            if (root.isTracker && !hasHistory) upowerSeedProc.running = true
        }
        onLoadFailed: {
            if (root.isTracker) upowerSeedProc.running = true
        }
    }

    // Seed from UPower's own history files — they go back weeks/months.
    // Merges with existing data so we don't overwrite our proc-annotated samples.
    Process {
        id: upowerSeedProc
        command: ["bash", "-c",
            'for f in $(ls -t /var/lib/upower/history-charge-*.dat 2>/dev/null | grep -v generic_id); do ' +
            '  awk \'$2>0 && $3!="unknown" {print $1, int($2+0.5)}\' "$f"; ' +
            'done'
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").filter(l => l.trim())
                const now = root.nowSec()
                const cutoff = now - 2 * 365 * 86400
                // Merge: existing samples take priority (they have proc names)
                const byTime = new Map()
                for (const line of lines) {
                    const p = line.trim().split(/\s+/)
                    if (p.length < 2) continue
                    const t = parseInt(p[0]), pct = parseInt(p[1])
                    if (isNaN(t) || isNaN(pct) || t < cutoff || pct <= 0) continue
                    byTime.set(t, [t, pct, ""])
                }
                // Existing samples overwrite UPower entries at same timestamp
                for (const s of root.batteryHistory) byTime.set(s[0], s)
                const merged = Array.from(byTime.values()).sort((a, b) => a[0] - b[0])
                if (merged.length > root.batteryHistory.length) {
                    root.batteryHistory = merged
                    historyFile.setText(JSON.stringify({ samples: merged }))
                }
            }
        }
    }

    // --- Usage tracking (on-battery / screen-on / last full) -----------------
    // This singleton is imported by several quickshell processes at once (the bar
    // shell, every Settings window). Only ONE of them may own the persisted
    // counters — otherwise they overwrite each other's file. We claim an flock;
    // the holder is the TRACKER (runs the timers, resets on a real unplug, writes
    // the file). Every other process is a read-only display that just reloads the
    // tracker's file to show its numbers.
    function nowSec() { return Math.floor(Date.now() / 1000); }
    property double onBatterySince: 0  // epoch when last unplugged (0 = plugged in)
    property double lastFullTime: 0    // epoch when battery last reached full
    property int screenOnSeconds: 0    // awake seconds since last unplug
    property int nowTick: 0            // bumped periodically so the values below stay live
    readonly property int onBatterySeconds: (nowTick, onBatterySince > 0 ? Math.max(0, nowSec() - onBatterySince) : 0)
    property double lastTick: 0
    property bool _lastPlugged: false  // plug-state baseline recorded at reconcile (edge detection)

    Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: {
            root.nowTick++;
            if (!root.isTracker) usageFile.reload();  // readers refresh from the tracker's file
        }
    }

    // Single-writer election. flock -n succeeds for exactly one process; that bash
    // stays alive (echoing TRACKER) until quickshell exits OR its parent dies,
    // releasing the lock so another process can take over. Losers exit and retry.
    property bool isTracker: false
    Process {
        id: trackerLock
        running: true
        command: ["bash", "-c",
            'exec 9>"${XDG_RUNTIME_DIR:-/tmp}/qs_battery_usage.lock"; ' +
            'flock -n 9 || exit 1; echo TRACKER; ' +
            'while kill -0 "$PPID" 2>/dev/null; do sleep 5; done']
        stdout: SplitParser { onRead: line => { if (line.trim() === "TRACKER") root.isTracker = true } }
        onExited: (code, status) => { root.isTracker = false; trackerRetryTimer.restart(); }
    }
    Timer { id: trackerRetryTimer; interval: 7000; repeat: false; onTriggered: trackerLock.running = true }

    // UPower settle gate. At process start UPower.onBattery defaults to false
    // (→ "plugged in") and only flips to the real value once D-Bus replies — that
    // initial flip is NOT a plug/unplug event. We wait for the device to report a
    // real state (or a timeout) before reconciling, so the settle is never a reset.
    readonly property bool upowerHasData: UPower.displayDevice.isLaptopBattery
        && UPower.displayDevice.state !== UPowerDeviceState.Unknown
    property bool upowerSettled: false
    onUpowerHasDataChanged: if (upowerHasData) root.upowerSettled = true
    Timer { interval: 6000; running: true; repeat: false; onTriggered: root.upowerSettled = true }  // fallback

    property bool usageLoaded: false   // persisted JSON has been read (or confirmed absent)
    property bool usageReady: false    // tracker has reconciled → live transitions are real

    // Tracker-only, once: reconcile persisted state with the now-settled hardware.
    // - Plugged in  → clock stopped (onBatterySince 0).
    // - On battery, with a prior record → KEEP it (a reload resumes, never resets).
    // - On battery, no record (first run / corrupt) → start the clock from now.
    // lastTick is pinned to now so the time the shell was dead isn't credited.
    function reconcileUsage() {
        if (!root.isTracker || !root.usageLoaded || !root.upowerSettled || root.usageReady) return;
        if (root.isPluggedIn) {
            root.onBatterySince = 0;
        } else {
            if (root.onBatterySince <= 0) {
                root.onBatterySince = root.nowSec();
                root.screenOnSeconds = 0;
            }
            root.lastTick = root.nowSec();
        }
        root._lastPlugged = root.isPluggedIn;  // edge baseline for onIsPluggedInChanged
        root.usageReady = true;
        root.persistUsage();
    }
    onIsTrackerChanged: reconcileUsage()
    onUsageLoadedChanged: reconcileUsage()
    onUpowerSettledChanged: reconcileUsage()

    // Screen-on time: only count while a display is actually powered (DPMS on). A
    // closed lid / blanked screen must NOT count. Suspend can't count either (the
    // timer is frozen) — and the per-tick cap stops a resume from dumping in the gap.
    Timer {
        interval: 30000
        running: root.isTracker && !root.isPluggedIn && root.usageReady
        repeat: true
        onTriggered: dpmsCheckProc.running = true   // check DPMS, then accumulate in onExited
    }
    Process {
        id: dpmsCheckProc
        command: ["bash", "-c", "hyprctl monitors -j 2>/dev/null | grep -c '\"dpmsStatus\": true'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const anyOn = (parseInt(text.trim()) || 0) > 0;
                const now = root.nowSec();
                if (root.lastTick === 0) root.lastTick = now;
                if (anyOn) root.screenOnSeconds += Math.min(now - root.lastTick, 45);  // cap → suspend gap ignored
                root.lastTick = now;
                root.persistUsage();
            }
        }
    }

    function persistUsage() {
        if (!root.isTracker) return;  // readers never write the shared file
        usageFile.setText(JSON.stringify({
            onBatterySince: root.onBatterySince,
            lastFullTime: root.lastFullTime,
            screenOnSeconds: root.screenOnSeconds
        }));
    }
    Component.onCompleted: { usageFile.reload(); historyFile.reload() }
    FileView {
        id: usageFile
        path: Qt.resolvedUrl(`${Directories.state}/user/battery_usage.json`)
        onLoaded: {
            try {
                const d = JSON.parse(usageFile.text());
                root.onBatterySince = d.onBatterySince ?? 0;
                root.lastFullTime = d.lastFullTime ?? 0;
                root.screenOnSeconds = d.screenOnSeconds ?? 0;
            } catch (e) {}
            root.usageLoaded = true;
            root.reconcileUsage();
        }
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound && root.isTracker) root.persistUsage();
            root.usageLoaded = true;
            root.reconcileUsage();
        }
    }
}
