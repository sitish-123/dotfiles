import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: page
    forceWidth: true

    // Debounced apply: rewrites hypridle.conf from the config and restarts hypridle.
    property bool idleReady: false
    Component.onCompleted: idleReady = true
    Timer {
        id: applyIdleDebounce
        interval: 800
        onTriggered: Quickshell.execDetached(["bash", "-c", "$HOME/.config/hypr/hyprland/scripts/apply-idle.sh"])
    }
    function applyIdle() { if (idleReady) applyIdleDebounce.restart(); }

    ContentSection {
        icon: "schedule"
        title: Translation.tr("Idle & lock")

        ConfigSwitch {
            buttonIcon: "coffee"
            text: Translation.tr("Keep system awake (no lock/sleep)")
            checked: Idle.inhibit
            onCheckedChanged: if (checked !== Idle.inhibit) Idle.toggleInhibit(checked)
            StyledToolTip {
                text: Translation.tr("Same as the sidebar 'Keep awake' toggle")
            }
        }
        ConfigSpinBox {
            icon: "lock_clock"
            text: Translation.tr("Lock screen after (minutes)")
            value: Config.options.idle.lockMinutes
            from: 1; to: 180
            onValueChanged: { Config.options.idle.lockMinutes = value; page.applyIdle(); }
        }
        ConfigSpinBox {
            icon: "brightness_low"
            text: Translation.tr("Turn off screen after (minutes)")
            value: Config.options.idle.screenOffMinutes
            from: 1; to: 180
            onValueChanged: { Config.options.idle.screenOffMinutes = value; page.applyIdle(); }
        }
        ConfigRow {
            uniform: false
            Layout.fillWidth: false
            ConfigSwitch {
                buttonIcon: "bedtime"
                text: Translation.tr("Auto-suspend when idle")
                checked: Config.options.idle.autoSuspend
                onCheckedChanged: { Config.options.idle.autoSuspend = checked; page.applyIdle(); }
            }
            ConfigSpinBox {
                enabled: Config.options.idle.autoSuspend
                text: Translation.tr("after (min)")
                value: Config.options.idle.suspendMinutes
                from: 1; to: 240
                onValueChanged: { Config.options.idle.suspendMinutes = value; page.applyIdle(); }
            }
        }
    }

    ContentSection {
        icon: "battery_android_question"
        title: Translation.tr("Battery thresholds")

        ConfigSpinBox {
            icon: "battery_low"
            text: Translation.tr("Low warning (%)")
            value: Config.options.battery.low
            from: 0; to: 100
            onValueChanged: Config.options.battery.low = value
        }
        ConfigSpinBox {
            icon: "battery_alert"
            text: Translation.tr("Critical warning (%)")
            value: Config.options.battery.critical
            from: 0; to: 100
            onValueChanged: Config.options.battery.critical = value
        }
        ConfigSpinBox {
            icon: "bedtime"
            text: Translation.tr("Auto-suspend at (%)")
            value: Config.options.battery.suspend
            from: 0; to: 100
            onValueChanged: Config.options.battery.suspend = value
        }
        ConfigSpinBox {
            icon: "battery_full"
            text: Translation.tr("Full charge reminder (%)")
            value: Config.options.battery.full
            from: 0; to: 100
            onValueChanged: Config.options.battery.full = value
        }
    }

    ContentSection {
        icon: "power_settings_new"
        title: Translation.tr("Power")

        ConfigSwitch {
            buttonIcon: "bedtime"
            text: Translation.tr("Automatic suspend on critical battery")
            checked: Config.options.battery.automaticSuspend
            onCheckedChanged: Config.options.battery.automaticSuspend = checked
        }

    }
}
