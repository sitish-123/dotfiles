import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    forceWidth: true

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

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: 6
            wrapMode: Text.Wrap
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            text: Translation.tr("Power profiles (performance/balanced/saver) need power-profiles-daemon, which is masked on this system for the network/boot tuning. Unmask it to enable profile switching here.")
        }
    }
}
