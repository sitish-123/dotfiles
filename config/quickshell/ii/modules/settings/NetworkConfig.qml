import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Quickshell

ContentPage {
    id: page
    forceWidth: true

    Component.onCompleted: if (Network.wifiEnabled) Network.rescanWifi()
    Timer {
        interval: 6000
        running: Network.wifiEnabled
        repeat: true
        onTriggered: Network.rescanWifi()
    }

    function signalIcon(s) {
        return s > 80 ? "signal_wifi_4_bar" : s > 60 ? "network_wifi_3_bar"
             : s > 40 ? "network_wifi_2_bar" : s > 20 ? "network_wifi_1_bar" : "signal_wifi_0_bar";
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
                StyledText { color: Appearance.colors.colOnSurface; text: Network.wifiEnabled ? Translation.tr("On") : Translation.tr("Off") }
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
                    text: "refresh"; iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colOnSurfaceVariant
                    RotationAnimator on rotation { running: Network.wifiScanning; loops: Animation.Infinite; from: 0; to: 360; duration: 900; onRunningChanged: if (!running) rescanIcon.rotation = 0 }
                }
            }
            StyledSwitch { checked: Network.wifiEnabled; onToggled: Network.enableWifi(checked) }
        }

        StyledText {
            visible: Network.friendlyWifiNetworks.length === 0
            Layout.fillWidth: true; Layout.topMargin: 8
            horizontalAlignment: Text.AlignHCenter
            color: Appearance.colors.colSubtext
            text: !Network.wifiEnabled ? Translation.tr("Turn on Wi-Fi to see networks")
                : Network.wifiScanning ? Translation.tr("Scanning for networks…") : Translation.tr("No networks found")
        }

        Repeater {
            model: ScriptModel { values: Network.friendlyWifiNetworks }
            delegate: ColumnLayout {
                id: row
                required property var modelData
                readonly property bool isActive: modelData?.active ?? false
                readonly property bool isEnterprise: modelData?.isEnterprise ?? false
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    MaterialSymbol {
                        text: page.signalIcon(row.modelData?.strength ?? 0)
                        iconSize: Appearance.font.pixelSize.larger
                        color: row.isActive ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        StyledText {
                            Layout.fillWidth: true; elide: Text.ElideRight
                            color: row.isActive ? Appearance.colors.colPrimary : Appearance.colors.colOnSurface
                            text: row.modelData?.ssid ?? Translation.tr("Unknown"); textFormat: Text.PlainText
                        }
                        StyledText {
                            Layout.fillWidth: true; elide: Text.ElideRight
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                            text: {
                                const p = [];
                                if (row.isActive) p.push(Translation.tr("Connected"));
                                p.push(`${row.modelData?.strength ?? 0}%`);
                                p.push(row.modelData?.band ?? "");
                                p.push(row.modelData?.securityLabel ?? "");
                                return p.filter(Boolean).join("  ·  ");
                            }
                        }
                    }
                    MaterialSymbol { visible: row.isActive; text: "check_circle"; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colPrimary }
                    DialogButton {
                        visible: (row.modelData?.isSecure ?? false) || row.isActive
                        buttonText: Translation.tr("Forget")
                        colBackground: Appearance.colors.colLayer4; colBackgroundHover: Appearance.colors.colLayer4Hover; colRipple: Appearance.colors.colLayer4Active
                        onClicked: if (row.modelData?.ssid) Network.forgetWifiNetwork(row.modelData.ssid)
                    }
                    DialogButton {
                        buttonText: row.isActive ? Translation.tr("Disconnect") : row.isEnterprise ? Translation.tr("Sign in") : Translation.tr("Connect")
                        onClicked: {
                            if (row.isActive) Network.disconnectWifiNetwork();
                            else if (row.isEnterprise) Network.connectToWifiEnterprise(row.modelData, entId.text, entPw.text);
                            else if (row.modelData?.askingPassword) Network.changePassword(row.modelData, pskPw.text);
                            else Network.connectToWifiNetwork(row.modelData);
                        }
                    }
                }

                MaterialTextField { // PSK password
                    id: pskPw
                    visible: (row.modelData?.askingPassword ?? false) && !row.isEnterprise && !row.isActive
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Password"); echoMode: TextInput.Password
                    onAccepted: Network.changePassword(row.modelData, pskPw.text)
                }
                MaterialTextField { // enterprise identity
                    id: entId
                    visible: row.isEnterprise && !row.isActive
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Identity (username)")
                }
                MaterialTextField { // enterprise password
                    id: entPw
                    visible: row.isEnterprise && !row.isActive
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Password"); echoMode: TextInput.Password
                    onAccepted: Network.connectToWifiEnterprise(row.modelData, entId.text, entPw.text)
                }
            }
        }
    }
}
