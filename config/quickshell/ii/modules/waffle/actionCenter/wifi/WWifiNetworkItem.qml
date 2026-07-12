import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.services.network
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.waffle.looks
import qs.modules.waffle.actionCenter

ExpandableChoiceButton {
    id: root
    required property WifiAccessPoint wifiNetwork

    // Auto-expand + reveal the password field when a secured connect needs a PSK.
    // The action-center list previously had no password UI at all, so secured/
    // enterprise networks just silently failed to connect.
    Connections {
        target: root.wifiNetwork
        function onAskingPasswordChanged() {
            if (root.wifiNetwork?.askingPassword) root.expanded = true;
        }
    }

    contentItem: RowLayout {
        id: contentItem
        spacing: 12

        FluentIcon { // Duotone hack
            Layout.bottomMargin: 2
            Layout.alignment: Qt.AlignTop
            property int strength: root.wifiNetwork?.strength ?? 0
            icon: "wifi-1"
            implicitSize: 30
            color: Looks.colors.inactiveIcon

            FluentIcon { // Signal
                property int strength: root.wifiNetwork?.strength ?? 0
                icon: WIcons.wifiIconForStrength(strength)
                implicitSize: 30

                FluentIcon { // Security
                    anchors {
                        right: parent.right
                        bottom: parent.bottom
                    }
                    visible: root?.wifiNetwork?.isSecure ?? false
                    icon: "lock-closed"
                    filled: true
                    implicitSize: 14           
                }
            }
        }

        ColumnLayout {
            Layout.topMargin: statusText.visible ? 4 : 7
            Layout.bottomMargin: 4
            Layout.alignment: Qt.AlignTop
            Layout.fillWidth: true
            spacing: 1

            Behavior on Layout.topMargin {
                animation: Looks.transition.move.createObject(this)
            }

            WText { // Network name
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.pixelSize: Looks.font.pixelSize.large
                text: root.wifiNetwork?.ssid ?? Translation.tr("Unknown")
                textFormat: Text.PlainText
            }
            WText { // Status
                id: statusText
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: root.wifiNetwork?.active ? Translation.tr("Connected") : root.wifiNetwork?.isSecure ? Translation.tr("Secured") : Translation.tr("Not secured")
                font.pixelSize: Looks.font.pixelSize.large
                color: Looks.colors.subfg
                visible: root.wifiNetwork?.active || root.expanded
                Behavior on opacity {
                    animation: Looks.transition.opacity.createObject(this)
                }
            }

            MaterialTextField { // PSK password — shown when a secured connect needs one
                id: passwordField
                visible: (root.wifiNetwork?.askingPassword ?? false) && !(root.wifiNetwork?.active ?? false)
                Layout.fillWidth: true
                Layout.rightMargin: 12
                placeholderText: Translation.tr("Password")
                echoMode: TextInput.Password
                inputMethodHints: Qt.ImhSensitiveData
                onAccepted: Network.changePassword(root.wifiNetwork, passwordField.text)
            }

            WButton {
                Layout.alignment: Qt.AlignRight
                horizontalAlignment: Text.AlignHCenter
                visible: root.expanded
                checked: !(root.wifiNetwork?.active ?? false)
                colBackground: Looks.colors.bg2
                colBackgroundHover: Looks.colors.bg2Hover
                colBackgroundActive: Looks.colors.bg2Active
                implicitHeight: 30
                implicitWidth: 148
                text: root.wifiNetwork?.active ? Translation.tr("Disconnect")
                    : root.wifiNetwork?.askingPassword ? Translation.tr("Sign in")
                    : Translation.tr("Connect")

                onClicked: {
                    if (root.wifiNetwork?.active) {
                        Network.disconnectWifiNetwork();
                    } else if (root.wifiNetwork?.askingPassword) {
                        Network.changePassword(root.wifiNetwork, passwordField.text);
                    } else {
                        Network.connectToWifiNetwork(root.wifiNetwork);
                    }
                }
            }
        }
    }
}
