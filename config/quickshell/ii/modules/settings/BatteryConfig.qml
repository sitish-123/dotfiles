import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    forceWidth: true

    function fmtDuration(sec) {
        sec = Math.round(sec);
        if (sec <= 0) return "—";
        const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60);
        if (h > 0) return `${h} h ${m} m`;
        if (m > 0) return `${m} m`;
        return `${sec} s`;
    }
    function timeAgo(epoch) {
        return (!epoch) ? "—" : fmtDuration(Battery.nowSec() - epoch) + Translation.tr(" ago");
    }

    // Reusable label/value row.
    component InfoRow: RowLayout {
        property string label: ""
        property string value: ""
        property string valueColor: Appearance.colors.colOnSurface
        Layout.fillWidth: true
        spacing: 12
        StyledText {
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
            text: label
        }
        Item { Layout.fillWidth: true }
        StyledText {
            font.pixelSize: Appearance.font.pixelSize.small
            color: valueColor
            horizontalAlignment: Text.AlignRight
            text: value
            textFormat: Text.PlainText
        }
    }

    ContentSection {
        icon: "battery_full"
        title: Translation.tr("Battery")

        ColumnLayout { // Big status header
            Layout.fillWidth: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                MaterialSymbol {
                    iconSize: 56
                    text: Battery.isCharging ? "battery_charging_full"
                        : Battery.percentage > 0.9 ? "battery_full"
                        : Battery.percentage > 0.6 ? "battery_5_bar"
                        : Battery.percentage > 0.35 ? "battery_3_bar"
                        : Battery.percentage > 0.15 ? "battery_2_bar" : "battery_alert"
                    color: Battery.isCritical ? Appearance.colors.colError
                        : Battery.isCharging ? Appearance.colors.colPrimary
                        : Appearance.colors.colOnSurface
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    StyledText {
                        font.pixelSize: Appearance.font.pixelSize.hugeass
                        color: Appearance.colors.colOnSurface
                        text: `${Math.round(Battery.percentage * 100)}%`
                    }
                    StyledText {
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colSubtext
                        text: {
                            if (!Battery.available) return Translation.tr("No battery");
                            if (Battery.isCharging) return Battery.timeToFull > 0
                                ? Translation.tr("Charging · %1 until full").arg(fmtDuration(Battery.timeToFull))
                                : Translation.tr("Charging");
                            if (Battery.isPluggedIn) return Translation.tr("Plugged in");
                            return Battery.timeToEmpty > 0
                                ? Translation.tr("On battery · %1 left").arg(fmtDuration(Battery.timeToEmpty))
                                : Translation.tr("On battery");
                        }
                    }
                }
            }
            StyledProgressBar {
                Layout.fillWidth: true
                value: Battery.percentage
            }
        }

        InfoRow {
            label: Translation.tr("Power draw")
            value: `${Math.abs(Battery.energyRate).toFixed(1)} W`
        }
        InfoRow {
            label: Translation.tr("Power source")
            value: Battery.isPluggedIn ? Translation.tr("AC adapter") : Translation.tr("Battery")
        }
    }

    ContentSection {
        icon: "schedule"
        title: Translation.tr("Usage")

        InfoRow {
            label: Translation.tr("On battery for")
            value: Battery.isPluggedIn ? Translation.tr("Plugged in") : fmtDuration(Battery.onBatterySeconds)
        }
        InfoRow {
            label: Translation.tr("Screen on (since unplug)")
            value: Battery.isPluggedIn ? "—" : fmtDuration(Battery.screenOnSeconds)
        }
        InfoRow {
            label: Translation.tr("Last full charge")
            value: timeAgo(Battery.lastFullTime)
        }
    }

    ContentSection {
        icon: "cardiology"
        title: Translation.tr("Health")

        InfoRow {
            label: Translation.tr("Battery health")
            value: `${Math.round(Battery.health)}%`
            valueColor: Battery.health < 80 ? Appearance.colors.colError : Appearance.colors.colOnSurface
        }
        InfoRow {
            label: Translation.tr("Charge cycles")
            value: Battery.cycleCount > 0 ? `${Battery.cycleCount}` : "—"
        }
        InfoRow {
            label: Translation.tr("Capacity")
            value: Battery.energyFull > 0
                ? `${Battery.energyFull.toFixed(1)} / ${Battery.energyFullDesign.toFixed(1)} Wh`
                : "—"
        }
        InfoRow {
            label: Translation.tr("Voltage")
            value: Battery.voltage > 0 ? `${Battery.voltage.toFixed(2)} V` : "—"
        }
        InfoRow {
            label: Translation.tr("Technology")
            value: Battery.technology || "—"
        }
    }
}
