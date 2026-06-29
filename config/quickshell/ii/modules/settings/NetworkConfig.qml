import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.services.network
import qs.modules.common
import qs.modules.common.widgets
import Quickshell

ContentPage {
    id: page
    forceWidth: true

    // Refetch the moment the page opens: the cached AP list shows instantly via
    // refreshNetworks(), and a full NIC rescan follows. In a freshly-opened settings
    // process Network.wifiEnabled isn't known yet here (it's read from nmcli async),
    // so DON'T gate the open-scan on it — also kick a rescan the instant wifi is
    // reported enabled, otherwise the first scan waits for the 6s timer.
    Component.onCompleted: {
        Network.refreshNetworks();
        if (Network.wifiEnabled) Network.rescanWifi();
    }
    Connections {
        target: Network
        function onWifiEnabledChanged() { if (Network.wifiEnabled) Network.rescanWifi(); }
    }
    Timer {
        interval: 6000
        running: Network.wifiEnabled
        repeat: true
        onTriggered: Network.rescanWifi()
    }
    Timer {
        interval: 2500
        running: Network.wifiEnabled
        repeat: true
        onTriggered: Network.refreshNetworks()
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

        StyledIndeterminateProgressBar {
            visible: Network.wifiScanning
            Layout.fillWidth: true
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
                readonly property bool isSecure: modelData?.isSecure ?? false
                readonly property bool isConnecting: Network.wifiConnectTarget === modelData
                readonly property bool expanded: (modelData?.expanded || modelData?.askingPassword) ?? false
                property string eapMethod: "peap"
                property bool shareShown: false
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 0

                MouseArea { // clickable header → expand/collapse
                    Layout.fillWidth: true
                    implicitHeight: header.implicitHeight + 12
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (row.modelData) row.modelData.expanded = !row.modelData.expanded

                    RowLayout {
                        id: header
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: 12
                        MaterialSymbol {
                            text: page.signalIcon(row.modelData?.strength ?? 0)
                            iconSize: Appearance.font.pixelSize.huge
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
                                    else if (row.isConnecting) p.push(Translation.tr("Connecting…"));
                                    p.push(`${row.modelData?.strength ?? 0}%`);
                                    p.push(row.modelData?.band ?? "");
                                    p.push(row.modelData?.securityLabel ?? "");
                                    return p.filter(Boolean).join("  ·  ");
                                }
                            }
                        }
                        MaterialSymbol {
                            visible: row.isSecure && !row.isActive
                            text: "lock"; iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colSubtext
                        }
                        MaterialSymbol {
                            visible: row.isActive
                            text: "check_circle"; iconSize: Appearance.font.pixelSize.huge
                            color: Appearance.colors.colPrimary
                        }
                        MaterialSymbol {
                            text: "expand_more"; iconSize: Appearance.font.pixelSize.huge
                            color: Appearance.colors.colSubtext
                            rotation: row.expanded ? 180 : 0
                            Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        }
                    }
                }

                Item { // animated expandable panel
                    Layout.fillWidth: true
                    clip: true
                    implicitHeight: row.expanded ? body.implicitHeight + 12 : 0
                    Behavior on implicitHeight { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    opacity: row.expanded ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 100 } }

                    ColumnLayout {
                        id: body
                        width: parent.width
                        y: 6
                        spacing: 10

                        Rectangle { // details card (active network)
                            Layout.fillWidth: true
                            visible: row.isActive
                            radius: Appearance.rounding.small
                            color: Appearance.m3colors.m3surfaceContainerHighest
                            implicitHeight: detailsCol.implicitHeight + 24

                            ColumnLayout {
                                id: detailsCol
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                                spacing: 7
                                Repeater {
                                    model: {
                                        const rows = [{ k: Translation.tr("BSSID"), v: row.modelData?.bssid ?? "" }];
                                        if (Network.ipAddress) rows.push({ k: Translation.tr("IP address"), v: Network.ipAddress });
                                        if (Network.gateway)   rows.push({ k: Translation.tr("Gateway"),    v: Network.gateway });
                                        if (Network.dns)       rows.push({ k: Translation.tr("DNS"),        v: Network.dns });
                                        return rows;
                                    }
                                    delegate: RowLayout {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        spacing: 8
                                        StyledText { font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colSubtext; text: modelData.k }
                                        Item { Layout.fillWidth: true }
                                        StyledText {
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            color: Appearance.colors.colOnSurfaceVariant
                                            horizontalAlignment: Text.AlignRight; elide: Text.ElideMiddle
                                            Layout.maximumWidth: parent.width * 0.62
                                            text: modelData.v; textFormat: Text.PlainText
                                        }
                                    }
                                }
                                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Appearance.colors.colOutlineVariant ?? Appearance.colors.colSubtext; opacity: 0.4 }
                                RowLayout {
                                    Layout.fillWidth: true
                                    StyledText { Layout.fillWidth: true; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnSurfaceVariant; text: Translation.tr("Connect automatically") }
                                    StyledSwitch { checked: Network.activeAutoconnect; onToggled: Network.setActiveAutoconnect(checked) }
                                }
                            }
                        }

                        Rectangle { // enterprise (802.1X) card
                            Layout.fillWidth: true
                            visible: row.isEnterprise && !row.isActive
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
                                    StyledText { Layout.fillWidth: true; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colSubtext; text: Translation.tr("EAP method") }
                                    Repeater {
                                        model: ["peap", "ttls"]
                                        delegate: DialogButton {
                                            required property string modelData
                                            buttonText: modelData.toUpperCase()
                                            colBackground: row.eapMethod === modelData ? Appearance.colors.colPrimary : Appearance.colors.colLayer4
                                            colText: row.eapMethod === modelData ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnSurfaceVariant
                                            onClicked: row.eapMethod = modelData
                                        }
                                    }
                                }
                                MaterialTextField {
                                    id: entId
                                    Layout.fillWidth: true
                                    placeholderText: Translation.tr("Identity (username)")
                                    inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                                }
                                MaterialTextField {
                                    id: entPw
                                    Layout.fillWidth: true
                                    placeholderText: Translation.tr("Password"); echoMode: TextInput.Password
                                    inputMethodHints: Qt.ImhSensitiveData
                                    onAccepted: Network.connectToWifiEnterprise(row.modelData, entId.text, entPw.text, row.eapMethod)
                                }
                            }
                        }

                        MaterialTextField { // PSK password
                            id: pskPw
                            visible: (row.modelData?.askingPassword ?? false) && !row.isEnterprise && !row.isActive
                            Layout.fillWidth: true
                            placeholderText: Translation.tr("Password"); echoMode: TextInput.Password
                            inputMethodHints: Qt.ImhSensitiveData
                            onAccepted: Network.changePassword(row.modelData, pskPw.text)
                        }

                        RowLayout { // actions
                            Layout.fillWidth: true
                            spacing: 8
                            DialogButton {
                                visible: row.isActive
                                Layout.fillWidth: true
                                buttonText: row.shareShown ? Translation.tr("Hide") : Translation.tr("Share")
                                colBackground: Appearance.colors.colLayer4; colBackgroundHover: Appearance.colors.colLayer4Hover; colRipple: Appearance.colors.colLayer4Active
                                onClicked: {
                                    row.shareShown = !row.shareShown;
                                    if (row.shareShown && row.modelData?.ssid) Network.loadShareInfo(row.modelData.ssid);
                                }
                            }
                            DialogButton {
                                visible: row.isSecure || row.isActive
                                Layout.fillWidth: true
                                buttonText: Translation.tr("Forget")
                                colBackground: Appearance.colors.colLayer4; colBackgroundHover: Appearance.colors.colLayer4Hover; colRipple: Appearance.colors.colLayer4Active
                                onClicked: if (row.modelData?.ssid) Network.forgetWifiNetwork(row.modelData.ssid)
                            }
                            DialogButton {
                                Layout.fillWidth: true
                                enabled: !(row.isEnterprise && !row.isActive) || entId.text.length > 0
                                buttonText: row.isActive ? Translation.tr("Disconnect") : row.isEnterprise ? Translation.tr("Sign in") : Translation.tr("Connect")
                                onClicked: {
                                    if (row.isActive) Network.disconnectWifiNetwork();
                                    else if (row.isEnterprise) Network.connectToWifiEnterprise(row.modelData, entId.text, entPw.text, row.eapMethod);
                                    else if (row.modelData?.askingPassword) Network.changePassword(row.modelData, pskPw.text);
                                    else Network.connectToWifiNetwork(row.modelData);
                                }
                            }
                        }

                        ColumnLayout { // share QR reveal (active)
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            visible: row.isActive && row.shareShown
                            spacing: 6
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: 184; implicitHeight: 184
                                radius: Appearance.rounding.small
                                color: "white"
                                visible: Network.shareQrPath.length > 0
                                Image {
                                    anchors.centerIn: parent
                                    width: 164; height: 164
                                    fillMode: Image.PreserveAspectFit; smooth: false; cache: false
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
                                    text: Network.sharePassword.length > 0 ? Network.sharePassword : Translation.tr("Open network"); textFormat: Text.PlainText
                                }
                                RippleButton {
                                    visible: Network.sharePassword.length > 0
                                    implicitWidth: 28; implicitHeight: 28
                                    buttonRadius: Appearance.rounding.full
                                    releaseAction: () => Quickshell.clipboardText = Network.sharePassword
                                    contentItem: MaterialSymbol { anchors.centerIn: parent; text: "content_copy"; iconSize: Appearance.font.pixelSize.normal; color: Appearance.colors.colOnSurfaceVariant }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    ContentSection {
        icon: "add"
        title: Translation.tr("Other")
        visible: Network.wifiEnabled

        ColumnLayout { // Add a hidden network (SSID not broadcast)
            id: hiddenSection
            property bool open: false
            Layout.fillWidth: true
            spacing: 6
            DialogButton {
                Layout.fillWidth: true
                buttonText: hiddenSection.open ? Translation.tr("Cancel") : Translation.tr("Add hidden network")
                colBackground: Appearance.colors.colLayer4; colBackgroundHover: Appearance.colors.colLayer4Hover; colRipple: Appearance.colors.colLayer4Active
                onClicked: hiddenSection.open = !hiddenSection.open
            }
            MaterialTextField {
                id: hiddenSsid
                visible: hiddenSection.open
                Layout.fillWidth: true
                placeholderText: Translation.tr("Network name (SSID)")
            }
            MaterialTextField {
                id: hiddenPass
                visible: hiddenSection.open
                Layout.fillWidth: true
                placeholderText: Translation.tr("Password (leave empty if open)"); echoMode: TextInput.Password
                inputMethodHints: Qt.ImhSensitiveData
                onAccepted: if (hiddenSsid.text.length > 0) { Network.connectHiddenNetwork(hiddenSsid.text, hiddenPass.text); hiddenSection.open = false; }
            }
            RowLayout {
                visible: hiddenSection.open
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                DialogButton {
                    enabled: hiddenSsid.text.length > 0
                    buttonText: Translation.tr("Connect")
                    onClicked: { Network.connectHiddenNetwork(hiddenSsid.text, hiddenPass.text); hiddenSection.open = false; }
                }
            }
        }
    }
}
