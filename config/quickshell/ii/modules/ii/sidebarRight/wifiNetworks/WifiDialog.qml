import qs
import qs.services
import qs.services.network
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

WindowDialog {
    id: root
    backgroundHeight: 600
    backgroundWidth: 400

    // Parse a standard Wi-Fi QR payload: WIFI:S:<ssid>;T:<WPA|WEP|nopass>;P:<pw>;H:<bool>;;
    // Handles backslash escaping of ; : , and \. Returns {ssid,pass,hidden} or null.
    function parseWifiQr(s) {
        if (!s || s.indexOf("WIFI:") !== 0) return null;
        s = s.slice(5);
        const fields = {};
        let buf = "", key = null;
        for (let p = 0; p < s.length; p++) {
            const c = s[p];
            if (c === "\\") { buf += (s[p + 1] ?? ""); p++; continue; }
            if (c === ";") { if (key !== null) fields[key] = buf; key = null; buf = ""; continue; }
            if (c === ":" && key === null) { key = buf; buf = ""; continue; }
            buf += c;
        }
        if (key !== null) fields[key] = buf;
        if (!fields.S) return null;
        return { ssid: fields.S, pass: fields.P || "", hidden: (fields.H || "").toLowerCase() === "true" };
    }

    // Reads decoded codes from zbarcam (which shows the webcam feed so you can aim).
    // On the first valid Wi-Fi QR: stop the camera and connect via the normal path.
    Process {
        id: qrScanProc
        command: ["zbarcam", "--raw", "-q"]
        stdout: SplitParser {
            onRead: data => {
                const parsed = root.parseWifiQr(data.trim());
                if (!parsed) return;
                qrScanProc.running = false; // closes the camera window
                qrStatus.text = Translation.tr("Connecting to %1…").arg(parsed.ssid);
                Network.connectHiddenNetwork(parsed.ssid, parsed.pass);
            }
        }
        onExited: (code, status) => {
            if (code !== 0 && qrStatus.text.length === 0)
                qrStatus.text = Translation.tr("Scanner closed — is the camera free? (needs zbar)");
        }
    }

    // Scan on open so the list is fresh, then keep refreshing while open. Show the
    // cached list instantly; don't gate the open-scan on wifiEnabled (not yet known
    // in a cold process) — also rescan the instant wifi is reported enabled.
    Component.onCompleted: {
        Network.refreshNetworks();
        if (Network.wifiEnabled) Network.rescanWifi();
        Network.loadHotspotConfig();
    }
    Connections {
        target: Network
        function onWifiEnabledChanged() { if (Network.wifiEnabled) Network.rescanWifi(); }
        function onHotspotBandChanged() { hotspotTab.band = Network.hotspotBand; }
    }
    // Periodic rescan to keep the list fresh — but NOT while the user is interacting
    // (expanding a network, typing a password, connecting, or using the hidden/QR
    // panels). A rescan rebuilds/reorders the model and would yank the input form
    // out from under them. It resumes the moment they're done.
    Timer {
        // Slow active rescan (finds new APs, ~1-8s). NM's environment changes slowly,
        // so 15s matches native applets and lets the scan spinner rest between runs
        // (a 6s interval re-fired before an 8s scan finished → spinner never stopped).
        interval: 15000
        running: Network.wifiEnabled && !Network.userInteracting
            && !hiddenSection.open && !qrScanProc.running
        repeat: true
        onTriggered: Network.rescanWifi()
    }
    Timer {
        // Cheap cached re-read (~25ms, no spinner) keeps the list + signal bars live
        // between the slow rescans — same as the settings Wi-Fi page.
        interval: 3000
        running: Network.wifiEnabled && !Network.userInteracting
            && !hiddenSection.open && !qrScanProc.running
        repeat: true
        onTriggered: Network.refreshNetworks()
    }

    // Compact round icon action (replaces the old full-width buttons).
    component IconAction: RippleButton {
        id: iconAction
        property string symbolName
        property bool accent: false
        implicitWidth: 36
        implicitHeight: 36
        buttonRadius: Appearance.rounding.full
        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            text: iconAction.symbolName
            iconSize: Appearance.font.pixelSize.larger
            color: iconAction.accent ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
        }
    }

    SecondaryTabBar {
        id: tabBar
        SecondaryTabButton { buttonIcon: "wifi"; buttonText: Translation.tr("Wi-Fi") }
        SecondaryTabButton { buttonIcon: "wifi_tethering"; buttonText: Translation.tr("Hotspot") }
    }

    StackLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        currentIndex: tabBar.currentIndex

        // ===================== Wi-Fi tab =====================
        ColumnLayout {
            spacing: 10

            RowLayout { // status + compact actions + power
                Layout.fillWidth: true
                spacing: 2
                StyledText {
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                    text: !Network.wifiEnabled ? Translation.tr("Wi-Fi is off")
                        : Network.active ? Translation.tr("Connected to %1").arg(Network.active.ssid)
                        : Network.wifiScanning ? Translation.tr("Scanning…")
                        : Translation.tr("Not connected")
                }
                IconAction {
                    symbolName: "password"
                    accent: hiddenSection.open
                    enabled: Network.wifiEnabled
                    releaseAction: () => hiddenSection.open = !hiddenSection.open
                    StyledToolTip { text: Translation.tr("Add hidden network") }
                }
                IconAction {
                    symbolName: "qr_code_scanner"
                    accent: qrScanProc.running
                    enabled: Network.wifiEnabled
                    releaseAction: () => {
                        if (qrScanProc.running) { qrScanProc.running = false; return; }
                        qrStatus.text = ""; qrScanProc.running = true;
                    }
                    StyledToolTip { text: Translation.tr("Scan Wi-Fi QR code") }
                }
                IconAction {
                    enabled: Network.wifiEnabled && !Network.wifiScanning
                    releaseAction: () => Network.rescanWifi()
                    StyledToolTip { text: Translation.tr("Rescan") }
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

            ColumnLayout { // Add a hidden network (SSID not broadcast) — revealed by the icon
                id: hiddenSection
                property bool open: false
                Layout.fillWidth: true
                visible: open && Network.wifiEnabled
                spacing: 6
                MaterialTextField {
                    id: hiddenSsid
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Network name (SSID)")
                }
                MaterialTextField {
                    id: hiddenPass
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Password (leave empty if open)")
                    echoMode: TextInput.Password
                    inputMethodHints: Qt.ImhSensitiveData
                    onAccepted: if (hiddenSsid.text.length > 0) Network.connectHiddenNetwork(hiddenSsid.text, hiddenPass.text)
                }
                RowLayout {
                    Layout.fillWidth: true
                    Item { Layout.fillWidth: true }
                    DialogButton {
                        buttonText: Translation.tr("Cancel")
                        colBackground: Appearance.colors.colLayer4
                        colBackgroundHover: Appearance.colors.colLayer4Hover
                        colRipple: Appearance.colors.colLayer4Active
                        onClicked: hiddenSection.open = false
                    }
                    DialogButton {
                        enabled: hiddenSsid.text.length > 0
                        buttonText: Translation.tr("Connect")
                        onClicked: {
                            Network.connectHiddenNetwork(hiddenSsid.text, hiddenPass.text);
                            hiddenSection.open = false;
                        }
                    }
                }
            }

            RowLayout { // QR scan status — revealed while the camera is up
                visible: qrScanProc.running || qrStatus.text.length > 0
                Layout.fillWidth: true
                spacing: 8
                StyledText {
                    id: qrStatus
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                    text: qrScanProc.running ? Translation.tr("Point the camera at a Wi-Fi QR…") : ""
                }
            }

            StyledText { // Empty / off states
                visible: Network.friendlyWifiNetworks.length === 0
                Layout.fillWidth: true
                Layout.topMargin: 16
                Layout.bottomMargin: 16
                horizontalAlignment: Text.AlignHCenter
                color: Appearance.colors.colSubtext
                text: !Network.wifiEnabled ? Translation.tr("Turn on Wi-Fi to see networks")
                    : Network.wifiScanning ? Translation.tr("Scanning for networks…")
                    : Translation.tr("No networks found")
            }

            ListView {
                visible: Network.friendlyWifiNetworks.length > 0
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.leftMargin: -Appearance.rounding.large
                Layout.rightMargin: -Appearance.rounding.large

                clip: true
                spacing: 0
                boundsBehavior: Flickable.StopAtBounds

                model: ScriptModel {
                    objectProp: "apId"
                    values: Network.friendlyWifiNetworks
                }
                delegate: WifiNetworkItem {
                    required property WifiAccessPoint modelData
                    wifiNetwork: modelData
                    width: ListView.view.width
                }
            }

            Item { Layout.fillHeight: true; visible: Network.friendlyWifiNetworks.length === 0 } // keep tab height stable
        }

        // ===================== Hotspot tab =====================
        ColumnLayout {
            id: hotspotTab
            property string band: Network.hotspotBand
            spacing: 10

            RowLayout { // header + power
                Layout.fillWidth: true
                spacing: 8
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    StyledText {
                        color: Appearance.colors.colOnSurface
                        text: Translation.tr("Wi-Fi hotspot")
                    }
                    StyledText {
                        Layout.fillWidth: true
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                        elide: Text.ElideRight
                        text: Network.hotspotEnabling ? Translation.tr("Applying…")
                            : Network.hotspotActive ? Translation.tr("On · %1 device(s)").arg(Network.hotspotClients)
                            : (hsPass.text.length > 0 && hsPass.text.length < 8) ? Translation.tr("Password needs 8+ characters")
                            : Network.hotspotBandLocked ? Translation.tr("Shares your Wi-Fi (stays connected)")
                            : Translation.tr("Off")
                    }
                }
                StyledSwitch {
                    enabled: !Network.hotspotEnabling && hsSsid.text.length > 0
                        && (hsPass.text.length === 0 || hsPass.text.length >= 8)
                    checked: Network.hotspotActive
                    onToggled: {
                        if (checked) Network.startHotspot(hsSsid.text, hsPass.text, hotspotTab.band);
                        else Network.stopHotspot();
                    }
                }
            }

            MaterialTextField {
                id: hsSsid
                Layout.fillWidth: true
                placeholderText: Translation.tr("Hotspot name (SSID)")
                text: Network.hotspotSsid
            }
            MaterialTextField {
                id: hsPass
                Layout.fillWidth: true
                placeholderText: Translation.tr("Password (8+ chars, empty = open)")
                echoMode: TextInput.Password
                inputMethodHints: Qt.ImhSensitiveData
                text: Network.hotspotPassword
            }
            RowLayout { // 2.4 GHz / 5 GHz band selector (locked to client channel on Wi-Fi)
                Layout.fillWidth: true
                spacing: 6
                StyledText {
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    text: Network.hotspotBandLocked ? Translation.tr("Band (follows Wi-Fi)") : Translation.tr("Band")
                }
                Repeater {
                    model: [{ label: Translation.tr("2.4 GHz"), val: "2.4" }, { label: Translation.tr("5 GHz"), val: "5" }]
                    delegate: DialogButton {
                        required property var modelData
                        enabled: !Network.hotspotBandLocked && !Network.hotspotActive
                        buttonText: modelData.label
                        colBackground: hotspotTab.band === modelData.val ? Appearance.colors.colPrimary : Appearance.colors.colLayer4
                        colText: hotspotTab.band === modelData.val ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnSurfaceVariant
                        onClicked: hotspotTab.band = modelData.val
                    }
                }
            }

            StyledText { // failure reason from the helper (e.g. DFS channel, dropped uplink)
                visible: Network.hotspotError.length > 0 && !Network.hotspotActive && !Network.hotspotEnabling
                Layout.fillWidth: true
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colError ?? Appearance.colors.colSubtext
                wrapMode: Text.WordWrap
                text: Network.hotspotError
            }
            StyledText { // explain the single-radio co-channel behaviour when on Wi-Fi
                visible: Network.hotspotBandLocked
                Layout.fillWidth: true
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                wrapMode: Text.WordWrap
                text: Translation.tr("On Wi-Fi, the hotspot shares that connection on the same channel (Wi-Fi stays up). Only works on non-DFS channels — 2.4 GHz or 5 GHz ch36-48/149-161, not radar channels like 52.")
            }

            Item { Layout.fillHeight: true } // push content to the top
        }
    }

    WindowDialogSeparator {}
    WindowDialogButtonRow {
        Item { Layout.fillWidth: true }
        DialogButton {
            buttonText: Translation.tr("Done")
            onClicked: { qrScanProc.running = false; root.dismiss(); }
        }
    }

    Component.onDestruction: qrScanProc.running = false // never leave the camera running
}
