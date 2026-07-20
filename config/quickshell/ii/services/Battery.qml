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
    property bool onBattery: available && UPower.onBattery

    // Glitch-filtered charge level. The Zenbook UX3405CA firmware emits transient
    // 0% readings (energy_now momentarily 0) at charge-state transitions — e.g. the
    // "pending-charge" flicker that once auto-suspended the machine at 93%. A device
    // that is running cannot truly be at 0%, and real discharge is gradual, so we
    // reject a bare 0 and any sudden single-sample drop, holding the last good value
    // until the next plausible reading. See the battery-tracker spikes note.
    property real rawPercentage: UPower.displayDevice?.percentage ?? 1
    property real percentage: rawPercentage > 0 ? rawPercentage : 1  // overwritten (binding broken) on first good sample
    property real _lastGoodPct: rawPercentage > 0 ? rawPercentage : 1
    onRawPercentageChanged: {
        if (rawPercentage <= 0 || (_lastGoodPct - rawPercentage) > 0.30) return; // glitch → keep last good
        _lastGoodPct = rawPercentage;
        percentage = rawPercentage;
    }

    readonly property bool allowAutomaticSuspend: Config.options.battery.automaticSuspend
    readonly property bool soundEnabled: Config.options.sounds.battery

    property bool isLow: available && (percentage <= Config.options.battery.low / 100)
    property bool isCritical: available && (percentage <= Config.options.battery.critical / 100)
    property bool isSuspending: available && (percentage <= Config.options.battery.suspend / 100)
    property bool isFull: available && (percentage >= Config.options.battery.full / 100)

    // Key off genuinely-on-battery (UPower.onBattery), NOT !isCharging: a plugged-in
    // charger can sit in "pending-charge" where isCharging is false, which used to let
    // a phantom-0 glitch fire auto-suspend while on AC. onBattery is false whenever the
    // charger is connected, regardless of the momentary charge state.
    property bool isLowAndNotCharging: isLow && onBattery
    property bool isCriticalAndNotCharging: isCritical && onBattery
    property bool isSuspendingAndNotCharging: allowAutomaticSuspend && isSuspending && onBattery
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

    // Suspend is destructive, so require the condition to hold for a few seconds before
    // acting — a lone bad sample that slips past the glitch filter can't put the machine
    // to sleep. Any recovery (charge/plug/level rise) cancels the pending suspend.
    Timer {
        id: suspendConfirm
        interval: 8000; repeat: false
        onTriggered: {
            if (root.available && root.isSuspendingAndNotCharging)
                Quickshell.execDetached(["bash", "-c", `systemctl suspend || loginctl suspend`]);
        }
    }
    onIsSuspendingAndNotChargingChanged: {
        if (root.available && isSuspendingAndNotCharging) suspendConfirm.restart();
        else suspendConfirm.stop();
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

    // Plug/unplug sound feedback only. ALL usage tracking (on-battery time, screen-on
    // time, last-full, and the history graph) is owned by the battery-tracker
    // systemd --user daemon — see system/user/battery-tracker.py in the dotfiles repo.
    // This singleton is a pure READER of the two state files that daemon writes; it
    // no longer elects a writer, resets a clock, or samples anything. Moving the
    // tracking out of this crash-prone, multi-process shell is what fixed the "battery
    // and SOT reset themselves midway" bug.
    //
    // _plugSoundReady skips the spurious false→true→false flip UPower emits while it
    // settles at startup, so we don't play a phantom plug chime on boot/reload.
    property bool _plugSoundReady: false
    Timer { interval: 6000; running: true; repeat: false; onTriggered: root._plugSoundReady = true }
    onIsPluggedInChanged: {
        if (!root._plugSoundReady || !root.available || !root.soundEnabled) return;
        Audio.playSystemSound(root.isPluggedIn ? "power-plug" : "power-unplug");
    }

    // --- Hardware extras (UPower doesn't expose all) -------------------------
    // Read-only sysfs snapshot — safe to run in every process (no shared writes).
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

    // --- Usage + history: READ-ONLY view of the daemon's state files ----------
    // battery_usage.json   = { onBatterySince, lastFullTime, screenOnSeconds }
    // battery_history.json = { samples: [[epoch, pct, watts, "proc:cpu,...", rx, tx]] }
    // The daemon (system/user/battery-tracker.py) is the sole writer; we just reload.
    function nowSec() { return Math.floor(Date.now() / 1000); }
    property double onBatterySince: 0  // epoch when last unplugged (0 = plugged in)
    property double lastFullTime: 0    // epoch when battery last reached full
    property int screenOnSeconds: 0    // awake seconds since last unplug
    property int nowTick: 0            // bumped every reload so onBatterySeconds stays live
    readonly property int onBatterySeconds: (nowTick, onBatterySince > 0 ? Math.max(0, nowSec() - onBatterySince) : 0)

    // Sample format: [timestamp, percent, watts, "proc:cpu%,...", rx_bytes, tx_bytes]
    property var batteryHistory: []

    // File reloads are EVENT-DRIVEN (inotify via watchChanges) — the daemon is the
    // sole writer, so we reload only when it actually writes, not on a poll. (Verified
    // watchChanges fires on the daemon's atomic rename-replace writes, not just
    // in-place ones.) The only timer left is a pure-JS tick so the live "On battery
    // for" label advances between the daemon's ~20s writes — it does no I/O.
    Timer { interval: 5000; running: true; repeat: true; onTriggered: root.nowTick++ }
    Timer { id: reloadDebounce; interval: 120; repeat: false
        onTriggered: { usageFile.reload(); historyFile.reload() } }
    Component.onCompleted: { usageFile.reload(); historyFile.reload() }

    FileView {
        id: usageFile
        path: Qt.resolvedUrl(`${Directories.state}/user/battery_usage.json`)
        watchChanges: true
        onFileChanged: reloadDebounce.restart()
        onLoaded: {
            try {
                const d = JSON.parse(usageFile.text());
                root.onBatterySince = d.onBatterySince ?? 0;
                root.lastFullTime = d.lastFullTime ?? 0;
                root.screenOnSeconds = d.screenOnSeconds ?? 0;
            } catch (e) {}
        }
    }
    FileView {
        id: historyFile
        path: Qt.resolvedUrl(`${Directories.state}/user/battery_history.json`)
        watchChanges: true
        onFileChanged: reloadDebounce.restart()
        onLoaded: {
            try { root.batteryHistory = JSON.parse(historyFile.text()).samples ?? [] } catch (e) {}
        }
    }
}
