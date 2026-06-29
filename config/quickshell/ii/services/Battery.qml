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
    property bool isPluggedIn: isCharging || chargeState == UPowerDeviceState.PendingCharge
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

    property real health: (function() {
        const devList = UPower.devices.values;
        for (let i = 0; i < devList.length; ++i) {
            const dev = devList[i];
            if (dev.isLaptopBattery && dev.healthSupported) {
                const health = dev.healthPercentage;
                if (health === 0) {
                    return 0.01;
                } else if (health < 1) {
                    return health * 100;
                } else {
                    return health;
                }
            }
        }
        return 0;
    })()


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
        // Usage tracking: reset the on-battery clock + screen-on counter on each unplug.
        if (root.isPluggedIn) {
            root.onBatterySince = 0;
        } else {
            root.onBatterySince = root.nowSec();
            root.screenOnSeconds = 0;
        }
        root.persistUsage();
        // Sounds
        if (!root.available || !root.soundEnabled) return;
        Audio.playSystemSound(isPluggedIn ? "power-plug" : "power-unplug");
    }

    onIsFullChanged: if (isFull) { root.lastFullTime = root.nowSec(); root.persistUsage(); }

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

    // --- Usage tracking (on-battery / screen-on / last full) -----------------
    function nowSec() { return Math.floor(Date.now() / 1000); }
    property double onBatterySince: 0  // epoch when last unplugged (0 = plugged in)
    property double lastFullTime: 0    // epoch when battery last reached full
    property int screenOnSeconds: 0    // awake seconds since last unplug
    readonly property int onBatterySeconds: onBatterySince > 0 ? Math.max(0, nowSec() - onBatterySince) : 0

    Timer { // accumulate awake/on-battery time
        interval: 60000
        running: !root.isPluggedIn
        repeat: true
        onTriggered: { root.screenOnSeconds += 60; root.persistUsage(); }
    }

    function persistUsage() {
        usageFile.setText(JSON.stringify({
            onBatterySince: root.onBatterySince,
            lastFullTime: root.lastFullTime,
            screenOnSeconds: root.screenOnSeconds
        }));
    }
    Component.onCompleted: usageFile.reload()
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
        }
        onLoadFailed: error => { if (error == FileViewError.FileNotFound) root.persistUsage(); }
    }
}
