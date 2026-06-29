import QtQuick
import QtQuick.Layouts
import qs.services
import qs.services.network
import qs.modules.common
import qs.modules.common.widgets
import "../ii/sidebarRight/wifiNetworks" as Wifi

ContentPage {
    forceWidth: true

    Component.onCompleted: if (Network.wifiEnabled) Network.rescanWifi()
    Timer {
        interval: 6000
        running: Network.wifiEnabled && parent.visible
        repeat: true
        onTriggered: Network.rescanWifi()
    }

    ContentSection {
        icon: "wifi"
        title: Translation.tr("Wi-Fi")

        RowLayout { // power + status + rescan
            Layout.fillWidth: true
            spacing: 10
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    color: Appearance.colors.colOnSurface
                    text: Network.wifiEnabled ? Translation.tr("On") : Translation.tr("Off")
                }
                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    text: !Network.wifiEnabled ? Translation.tr("Wi-Fi is off")
                        : Network.active ? Translation.tr("Connected to %1").arg(Network.active.ssid)
                        : Network.wifiScanning ? Translation.tr("Scanning…")
                        : Translation.tr("Not connected")
                }
            }
            RippleButton {
                implicitWidth: 34; implicitHeight: 34
                buttonRadius: Appearance.rounding.full
                enabled: Network.wifiEnabled && !Network.wifiScanning
                releaseAction: () => Network.rescanWifi()
                contentItem: MaterialSymbol {
                    id: rescanIcon
                    anchors.centerIn: parent
                    text: "refresh"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colOnSurfaceVariant
                    RotationAnimator on rotation {
                        running: Network.wifiScanning
                        loops: Animation.Infinite
                        from: 0; to: 360; duration: 900
                        onRunningChanged: if (!running) rescanIcon.rotation = 0
                    }
                }
            }
            StyledSwitch {
                checked: Network.wifiEnabled
                onToggled: Network.enableWifi(checked)
            }
        }

        StyledText {
            visible: Network.friendlyWifiNetworks.length === 0
            Layout.fillWidth: true
            Layout.topMargin: 8
            horizontalAlignment: Text.AlignHCenter
            color: Appearance.colors.colSubtext
            text: !Network.wifiEnabled ? Translation.tr("Turn on Wi-Fi to see networks")
                : Network.wifiScanning ? Translation.tr("Scanning for networks…")
                : Translation.tr("No networks found")
        }

        Repeater {
            model: ScriptModel { values: Network.friendlyWifiNetworks }
            delegate: Wifi.WifiNetworkItem {
                required property WifiAccessPoint modelData
                wifiNetwork: modelData
                Layout.fillWidth: true
            }
        }
    }
}
