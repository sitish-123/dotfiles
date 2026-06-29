import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: root
    forceWidth: true

    // Top processes by CPU — the closest thing to "what's draining the battery" on Linux.
    property var procModel: []
    Process {
        id: procTop
        command: ["bash", "-c", "ps -eo comm,%cpu,%mem --sort=-%cpu --no-headers | head -n 8"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.procModel = text.trim().split("\n").filter(l => l.length).map(l => {
                    const p = l.trim().split(/\s+/);
                    const mem = parseFloat(p.pop());
                    const cpu = parseFloat(p.pop());
                    return { name: p.join(" "), cpu: cpu, mem: mem };
                });
            }
        }
    }
    Timer {
        // Only polls while the Battery page is actually on screen — zero cost otherwise.
        running: root.visible
        repeat: true
        interval: 5000
        triggeredOnStart: true
        onTriggered: procTop.running = true
    }

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

    ContentSection {
        icon: "monitoring"
        title: Translation.tr("What's using power")

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            text: Translation.tr("Linux can't attribute battery use per app. These are the busiest processes by CPU — the main controllable drain — refreshed live. (For deeper device-level analysis, run 'sudo powertop' in a terminal.)")
        }

        Repeater {
            model: root.procModel
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 10
                StyledText {
                    Layout.preferredWidth: 150
                    elide: Text.ElideRight
                    text: modelData.name
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnSurface
                }
                StyledProgressBar {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    value: Math.max(0, Math.min(1, modelData.cpu / 100))
                }
                StyledText {
                    Layout.preferredWidth: 64
                    horizontalAlignment: Text.AlignRight
                    text: `${modelData.cpu.toFixed(0)}% cpu`
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }
            }
        }
        StyledText {
            visible: root.procModel.length === 0
            Layout.fillWidth: true
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
            text: Translation.tr("Reading processes…")
        }
    }
}
