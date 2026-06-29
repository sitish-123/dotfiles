import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.services.network
import QtQuick
import QtQuick.Layouts

DialogListItem {
    id: root
    required property WifiAccessPoint wifiNetwork
    readonly property bool isActive: wifiNetwork?.active ?? false
    readonly property bool expanded: (wifiNetwork?.expanded || wifiNetwork?.askingPassword) ?? false
    readonly property int strength: wifiNetwork?.strength ?? 0

    enabled: !(Network.wifiConnectTarget === root.wifiNetwork && !isActive)
    active: (root.expanded || root.isActive) ?? false
    // Tap toggles the details/actions panel (self-contained — no external app).
    onClicked: if (root.wifiNetwork) root.wifiNetwork.expanded = !root.wifiNetwork.expanded

    function signalIcon(s) {
        return s > 80 ? "signal_wifi_4_bar" : s > 60 ? "network_wifi_3_bar"
             : s > 40 ? "network_wifi_2_bar" : s > 20 ? "network_wifi_1_bar"
             : "signal_wifi_0_bar";
    }

    contentItem: ColumnLayout {
        anchors {
            fill: parent
            topMargin: root.verticalPadding
            bottomMargin: root.verticalPadding
            leftMargin: root.horizontalPadding
            rightMargin: root.horizontalPadding
        }
        spacing: 0

        RowLayout { // Header: signal, name, band/security chips, state
            spacing: 10
            Layout.fillWidth: true

            MaterialSymbol {
                iconSize: Appearance.font.pixelSize.larger
                text: root.signalIcon(root.strength)
                color: root.isActive ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    Layout.fillWidth: true
                    color: Appearance.colors.colOnSurfaceVariant
                    elide: Text.ElideRight
                    text: root.wifiNetwork?.ssid ?? Translation.tr("Unknown")
                    textFormat: Text.PlainText
                }
                StyledText { // subtitle: state / band / security
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                    text: {
                        const parts = [];
                        if (root.isActive) parts.push(Translation.tr("Connected"));
                        else if (Network.wifiConnectTarget === root.wifiNetwork) parts.push(Translation.tr("Connecting…"));
                        parts.push(`${root.strength}%`);
                        parts.push(root.wifiNetwork?.band ?? "");
                        parts.push(root.wifiNetwork?.securityLabel ?? "");
                        return parts.filter(Boolean).join("  ·  ");
                    }
                }
            }
            MaterialSymbol {
                visible: (root.wifiNetwork?.isSecure ?? false) && !root.isActive
                text: "lock"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colSubtext
            }
            MaterialSymbol {
                visible: root.isActive
                text: "check_circle"
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colPrimary
            }
            MaterialSymbol { // expand chevron
                text: "expand_more"
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colSubtext
                rotation: root.expanded ? 180 : 0
                Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }
        }

        Item { // Animated expandable panel: details + password + actions
            Layout.fillWidth: true
            clip: true
            implicitHeight: root.expanded ? detailsCol.implicitHeight + 10 : 0
            Behavior on implicitHeight {
                NumberAnimation { duration: 250; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.animationCurves.emphasizedDecel }
            }

            ColumnLayout {
                id: detailsCol
                width: parent.width
                y: 8
                spacing: 6

                // Detail rows
                Repeater {
                    model: {
                        const rows = [
                            { k: Translation.tr("Signal"),   v: `${root.strength}%` },
                            { k: Translation.tr("Security"), v: root.wifiNetwork?.securityLabel ?? "" },
                            { k: Translation.tr("Band"),     v: root.wifiNetwork?.band ?? "" },
                            { k: Translation.tr("BSSID"),    v: root.wifiNetwork?.bssid ?? "" },
                        ];
                        if (root.isActive) {
                            if (Network.ipAddress) rows.push({ k: Translation.tr("IP address"), v: Network.ipAddress });
                            if (Network.gateway)   rows.push({ k: Translation.tr("Gateway"),    v: Network.gateway });
                            if (Network.dns)       rows.push({ k: Translation.tr("DNS"),        v: Network.dns });
                        }
                        return rows;
                    }
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 8
                        StyledText {
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                            text: modelData.k
                        }
                        Item { Layout.fillWidth: true }
                        StyledText {
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnSurfaceVariant
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideMiddle
                            Layout.maximumWidth: parent.width * 0.6
                            text: modelData.v
                            textFormat: Text.PlainText
                        }
                    }
                }

                MaterialTextField { // Password (secure networks needing auth)
                    id: passwordField
                    visible: root.wifiNetwork?.askingPassword ?? false
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    placeholderText: Translation.tr("Password")
                    echoMode: TextInput.Password
                    inputMethodHints: Qt.ImhSensitiveData
                    onAccepted: Network.changePassword(root.wifiNetwork, passwordField.text)
                }

                RowLayout { // Actions
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 8
                    Item { Layout.fillWidth: true }

                    DialogButton {
                        visible: (root.wifiNetwork?.isSecure ?? false) || root.isActive
                        buttonText: Translation.tr("Forget")
                        colBackground: Appearance.colors.colLayer4
                        colBackgroundHover: Appearance.colors.colLayer4Hover
                        colRipple: Appearance.colors.colLayer4Active
                        onClicked: if (root.wifiNetwork?.ssid) Network.forgetWifiNetwork(root.wifiNetwork.ssid)
                    }
                    DialogButton {
                        visible: root.isActive
                        buttonText: Translation.tr("Disconnect")
                        onClicked: Network.disconnectWifiNetwork()
                    }
                    DialogButton {
                        visible: !root.isActive
                        buttonText: root.wifiNetwork?.askingPassword ? Translation.tr("Connect with password") : Translation.tr("Connect")
                        onClicked: {
                            if (root.wifiNetwork?.askingPassword)
                                Network.changePassword(root.wifiNetwork, passwordField.text);
                            else
                                Network.connectToWifiNetwork(root.wifiNetwork);
                        }
                    }
                }
            }
        }
    }
}
