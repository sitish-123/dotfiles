import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    forceWidth: true

    ContentSection {
        icon: "system_update"
        title: Translation.tr("System updates")

        // --- Status -----------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.bottomMargin: 4
            spacing: 12

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                iconSize: 32
                fill: 1
                text: !Updates.available ? "help"
                    : Updates.checking ? "sync"
                    : Updates.count > 0 ? "deployed_code_update"
                    : "check_circle"
                color: (Updates.available && Updates.count > 0) ? Appearance.colors.colOnLayer1 : Appearance.colors.colOnLayer1
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer1
                    text: !Updates.available ? Translation.tr("Update check unavailable")
                        : Updates.checking ? Translation.tr("Checking for updates…")
                        : Updates.count > 0 ? Translation.tr("%1 package update(s) available").arg(Updates.count)
                        : Translation.tr("Your system is up to date")
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: !Updates.available
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    wrapMode: Text.WordWrap
                    text: Translation.tr("Install 'pacman-contrib' (provides checkupdates) to enable update checking.")
                }
            }
        }

        // --- Actions ----------------------------------------------------
        ConfigRow {
            uniform: true
            RippleButtonWithIcon {
                Layout.fillWidth: true
                materialIcon: "refresh"
                enabled: Updates.available && !Updates.checking
                mainText: Updates.checking ? Translation.tr("Checking…") : Translation.tr("Check now")
                onClicked: Updates.refresh()
            }
            RippleButtonWithIcon {
                Layout.fillWidth: true
                materialIcon: "download"
                mainText: Translation.tr("Update now")
                onClicked: Quickshell.execDetached(["bash", "-c", Config.options.apps.update])
                StyledToolTip {
                    text: Translation.tr("Runs: %1").arg(Config.options.apps.update)
                }
            }
        }
    }

    // --- Preferences ----------------------------------------------------
    ContentSection {
        icon: "tune"
        title: Translation.tr("Update checking")

        ConfigSwitch {
            buttonIcon: "schedule"
            text: Translation.tr("Periodically check for updates")
            checked: Config.options.updates.enableCheck
            onCheckedChanged: Config.options.updates.enableCheck = checked
        }
        ConfigRow {
            enabled: Config.options.updates.enableCheck
            ConfigSpinBox {
                icon: "timer"
                text: Translation.tr("Check interval (minutes)")
                value: Config.options.updates.checkInterval
                from: 5
                to: 1440
                stepSize: 5
                onValueChanged: Config.options.updates.checkInterval = value
            }
        }
        ConfigRow {
            uniform: true
            enabled: Config.options.updates.enableCheck
            ConfigSpinBox {
                icon: "info"
                text: Translation.tr("Advise at (packages)")
                value: Config.options.updates.adviseUpdateThreshold
                from: 0
                to: 1000
                stepSize: 5
                onValueChanged: Config.options.updates.adviseUpdateThreshold = value
            }
            ConfigSpinBox {
                icon: "priority_high"
                text: Translation.tr("Strongly advise at")
                value: Config.options.updates.stronglyAdviseUpdateThreshold
                from: 0
                to: 2000
                stepSize: 5
                onValueChanged: Config.options.updates.stronglyAdviseUpdateThreshold = value
            }
        }
    }
}
