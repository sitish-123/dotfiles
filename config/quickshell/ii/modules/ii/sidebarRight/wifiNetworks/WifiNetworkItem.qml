import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
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
    readonly property bool isSecure: wifiNetwork?.isSecure ?? false
    readonly property bool expanded: (wifiNetwork?.expanded || wifiNetwork?.askingPassword) ?? false
    readonly property int strength: wifiNetwork?.strength ?? 0
    property string eapMethod: "peap"   // enterprise EAP method (peap/ttls)
    property bool shareShown: false      // active network: QR + password reveal

    enabled: !(Network.wifiConnectTarget === root.wifiNetwork && !isActive)
    active: (root.expanded || root.isActive) ?? false
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

        RowLayout { // Header
            spacing: 12
            Layout.fillWidth: true

            MaterialSymbol {
                iconSize: Appearance.font.pixelSize.huge
                text: root.signalIcon(root.strength)
                color: root.isActive ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                StyledText {
                    Layout.fillWidth: true
                    color: root.isActive ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                    elide: Text.ElideRight
                    text: root.wifiNetwork?.ssid ?? Translation.tr("Unknown")
                    textFormat: Text.PlainText
                }
                StyledText { // status · signal · band · security
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
                visible: root.isSecure && !root.isActive
                text: "lock"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colSubtext
            }
            MaterialSymbol {
                visible: root.isActive
                text: "check_circle"
                iconSize: Appearance.font.pixelSize.huge
                color: Appearance.colors.colPrimary
            }
            MaterialSymbol {
                text: "expand_more"
                iconSize: Appearance.font.pixelSize.huge
                color: Appearance.colors.colSubtext
                rotation: root.expanded ? 180 : 0
                Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }
        }

        Item { // Animated expandable panel
            Layout.fillWidth: true
            clip: true
            implicitHeight: root.expanded ? body.implicitHeight + 12 : 0
            Behavior on implicitHeight {
                NumberAnimation { duration: 220; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.animationCurves.emphasizedDecel }
            }
            opacity: root.expanded ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }

            ColumnLayout {
                id: body
                width: parent.width
                y: 12
                spacing: 10

                Rectangle { // Details card (active network)
                    Layout.fillWidth: true
                    visible: root.isActive
                    radius: Appearance.rounding.small
                    color: Appearance.m3colors.m3surfaceContainerHighest
                    implicitHeight: detailsCol.implicitHeight + 24

                    ColumnLayout {
                        id: detailsCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                        spacing: 7

                        Repeater {
                            model: {
                                const rows = [{ k: Translation.tr("BSSID"), v: root.wifiNetwork?.bssid ?? "" }];
                                if (Network.ipAddress) rows.push({ k: Translation.tr("IP address"), v: Network.ipAddress });
                                if (Network.gateway)   rows.push({ k: Translation.tr("Gateway"),    v: Network.gateway });
                                if (Network.dns)       rows.push({ k: Translation.tr("DNS"),        v: Network.dns });
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
                                    Layout.maximumWidth: parent.width * 0.62
                                    text: modelData.v
                                    textFormat: Text.PlainText
                                }
                            }
                        }
                        Rectangle { // divider
                            Layout.fillWidth: true
                            Layout.topMargin: 1
                            Layout.bottomMargin: 1
                            implicitHeight: 1
                            color: Appearance.colors.colOutlineVariant ?? Appearance.colors.colSubtext
                            opacity: 0.4
                        }
                        RowLayout { // auto-connect
                            Layout.fillWidth: true
                            StyledText {
                                Layout.fillWidth: true
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnSurfaceVariant
                                text: Translation.tr("Connect automatically")
                            }
                            StyledSwitch {
                                checked: Network.activeAutoconnect
                                onToggled: Network.setActiveAutoconnect(checked)
                            }
                        }
                    }
                }

                Rectangle { // Enterprise (802.1X) card
                    Layout.fillWidth: true
                    visible: root.isEnterprise && !root.isActive
                    radius: Appearance.rounding.small
                    color: Appearance.m3colors.m3surfaceContainerHighest
                    implicitHeight: entCol.implicitHeight + 24

                    ColumnLayout {
                        id: entCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            StyledText {
                                Layout.fillWidth: true
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                                text: Translation.tr("EAP method")
                            }
                            Repeater {
                                model: ["peap", "ttls"]
                                delegate: GroupButton {
                                    required property string modelData
                                    baseWidth: 54
                                    contentItem: StyledText {
                                        anchors.centerIn: parent
                                        text: modelData.toUpperCase()
                                        color: root.eapMethod === modelData ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnSurfaceVariant
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                    }
                                    toggled: root.eapMethod === modelData
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
                }

                MaterialTextField { // PSK password
                    id: passwordField
                    visible: (root.wifiNetwork?.askingPassword ?? false) && !root.isEnterprise && !root.isActive
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Password")
                    echoMode: TextInput.Password
                    inputMethodHints: Qt.ImhSensitiveData
                    onAccepted: Network.changePassword(root.wifiNetwork, passwordField.text)
                }

                RowLayout { // One clean action row (equal-width)
                    Layout.fillWidth: true
                    spacing: 8

                    DialogButton {
                        visible: root.isActive
                        Layout.fillWidth: true
                        buttonText: root.shareShown ? Translation.tr("Hide") : Translation.tr("Share")
                        colBackground: Appearance.colors.colLayer4
                        colBackgroundHover: Appearance.colors.colLayer4Hover
                        colRipple: Appearance.colors.colLayer4Active
                        onClicked: {
                            root.shareShown = !root.shareShown;
                            if (root.shareShown && root.wifiNetwork?.ssid)
                                Network.loadShareInfo(root.wifiNetwork.ssid);
                        }
                    }
                    DialogButton {
                        visible: root.isSecure || root.isActive
                        Layout.fillWidth: true
                        buttonText: Translation.tr("Forget")
                        colBackground: Appearance.colors.colLayer4
                        colBackgroundHover: Appearance.colors.colLayer4Hover
                        colRipple: Appearance.colors.colLayer4Active
                        onClicked: if (root.wifiNetwork?.ssid) Network.forgetWifiNetwork(root.wifiNetwork.ssid)
                    }
                    DialogButton { // primary action
                        Layout.fillWidth: true
                        enabled: !(root.isEnterprise && !root.isActive) || identityField.text.length > 0
                        buttonText: root.isActive ? Translation.tr("Disconnect")
                            : root.isEnterprise ? Translation.tr("Sign in")
                            : root.wifiNetwork?.askingPassword ? Translation.tr("Connect")
                            : Translation.tr("Connect")
                        onClicked: {
                            if (root.isActive)
                                Network.disconnectWifiNetwork();
                            else if (root.isEnterprise)
                                Network.connectToWifiEnterprise(root.wifiNetwork, identityField.text, entPasswordField.text, root.eapMethod);
                            else if (root.wifiNetwork?.askingPassword)
                                Network.changePassword(root.wifiNetwork, passwordField.text);
                            else
                                Network.connectToWifiNetwork(root.wifiNetwork);
                        }
                    }
                }

                ColumnLayout { // Share QR reveal (active)
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.isActive && root.shareShown
                    spacing: 6

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 184
                        implicitHeight: 184
                        radius: Appearance.rounding.small
                        color: "white"
                        visible: Network.shareQrPath.length > 0
                        Image {
                            anchors.centerIn: parent
                            width: 164; height: 164
                            fillMode: Image.PreserveAspectFit
                            smooth: false
                            cache: false
                            source: Network.shareQrPath.length > 0 ? ("file://" + Network.shareQrPath) : ""
                            sourceSize.width: 164; sourceSize.height: 164
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
        }
    }
}
