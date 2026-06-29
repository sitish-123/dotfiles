import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.services.network
import QtQuick
import QtQuick.Layouts
import Quickshell

DialogListItem {
    id: root
    required property WifiAccessPoint wifiNetwork
    readonly property bool isActive: wifiNetwork?.active ?? false
    readonly property bool isEnterprise: wifiNetwork?.isEnterprise ?? false
    readonly property bool expanded: (wifiNetwork?.expanded || wifiNetwork?.askingPassword) ?? false
    readonly property int strength: wifiNetwork?.strength ?? 0
    property string eapMethod: "peap"   // enterprise EAP method (peap/ttls)
    property bool shareShown: false      // active network: QR + password reveal

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

                ColumnLayout { // Active network: auto-connect + share (QR + password)
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    visible: root.isActive
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        StyledText {
                            Layout.fillWidth: true
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                            text: Translation.tr("Connect automatically")
                        }
                        StyledSwitch {
                            checked: Network.activeAutoconnect
                            onToggled: Network.setActiveAutoconnect(checked)
                        }
                    }

                    DialogButton {
                        Layout.fillWidth: true
                        buttonText: root.shareShown ? Translation.tr("Hide share") : Translation.tr("Share Wi-Fi")
                        colBackground: Appearance.colors.colLayer4
                        colBackgroundHover: Appearance.colors.colLayer4Hover
                        colRipple: Appearance.colors.colLayer4Active
                        onClicked: {
                            root.shareShown = !root.shareShown;
                            if (root.shareShown && root.wifiNetwork?.ssid)
                                Network.loadShareInfo(root.wifiNetwork.ssid);
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.shareShown
                        spacing: 6

                        Rectangle { // white frame so the QR scans on dark themes
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: 176
                            implicitHeight: 176
                            radius: Appearance.rounding.small
                            color: "white"
                            visible: Network.shareQrPath.length > 0
                            Image {
                                anchors.centerIn: parent
                                width: 160; height: 160
                                fillMode: Image.PreserveAspectFit
                                smooth: false
                                cache: false
                                source: Network.shareQrPath.length > 0 ? ("file://" + Network.shareQrPath) : ""
                                sourceSize.width: 160; sourceSize.height: 160
                            }
                        }
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 6
                            StyledText {
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnSurfaceVariant
                                text: Network.sharePassword.length > 0 ? Network.sharePassword : Translation.tr("Open network")
                                textFormat: Text.PlainText
                            }
                            RippleButton {
                                visible: Network.sharePassword.length > 0
                                implicitWidth: 28
                                implicitHeight: 28
                                buttonRadius: Appearance.rounding.full
                                releaseAction: () => Quickshell.clipboardText = Network.sharePassword
                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "content_copy"
                                    iconSize: Appearance.font.pixelSize.normal
                                    color: Appearance.colors.colOnSurfaceVariant
                                }
                            }
                        }
                    }
                }

                ColumnLayout { // Enterprise (802.1X) login: EAP method + identity + password
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 6
                    visible: root.isEnterprise && !root.isActive

                    RowLayout { // EAP method
                        Layout.fillWidth: true
                        spacing: 8
                        StyledText {
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                            text: Translation.tr("EAP method")
                        }
                        Item { Layout.fillWidth: true }
                        Repeater {
                            model: ["peap", "ttls"]
                            delegate: DialogButton {
                                required property string modelData
                                buttonText: modelData.toUpperCase()
                                toggled: root.eapMethod === modelData
                                colBackground: root.eapMethod === modelData ? Appearance.colors.colPrimary : Appearance.colors.colLayer4
                                colBackgroundHover: Appearance.colors.colLayer4Hover
                                onClicked: root.eapMethod = modelData
                            }
                        }
                    }
                    MaterialTextField {
                        id: identityField
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Identity (username)")
                        inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                    }
                    MaterialTextField {
                        id: entPasswordField
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Password")
                        echoMode: TextInput.Password
                        inputMethodHints: Qt.ImhSensitiveData
                        onAccepted: Network.connectToWifiEnterprise(root.wifiNetwork, identityField.text, entPasswordField.text, root.eapMethod)
                    }
                }

                MaterialTextField { // PSK password (regular secured networks)
                    id: passwordField
                    visible: (root.wifiNetwork?.askingPassword ?? false) && !root.isEnterprise
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
                        enabled: !root.isEnterprise || identityField.text.length > 0
                        buttonText: root.isEnterprise ? Translation.tr("Sign in")
                            : root.wifiNetwork?.askingPassword ? Translation.tr("Connect with password")
                            : Translation.tr("Connect")
                        onClicked: {
                            if (root.isEnterprise)
                                Network.connectToWifiEnterprise(root.wifiNetwork, identityField.text, entPasswordField.text, root.eapMethod);
                            else if (root.wifiNetwork?.askingPassword)
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
