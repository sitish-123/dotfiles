import qs
import qs.services
import qs.services.network
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
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
    }
    Connections {
        target: Network
        function onWifiEnabledChanged() { if (Network.wifiEnabled) Network.rescanWifi(); }
    }
    // Periodic rescan to keep the list fresh — but NOT while the user is interacting
    // (expanding a network, typing a password, connecting, or using the hidden/QR
    // panels). A rescan rebuilds/reorders the model and would yank the input form
    // out from under them. It resumes the moment they're done.
    Timer {
        interval: 6000
        running: Network.wifiEnabled && !Network.userInteracting
            && !hiddenSection.open && !qrScanProc.running
        repeat: true
        onTriggered: Network.rescanWifi()
    }

    RowLayout { // Title + Wi-Fi toggle
        Layout.fillWidth: true
        spacing: 8
        WindowDialogTitle {
            Layout.fillWidth: true
            text: Translation.tr("Wi-Fi")
        }
        StyledSwitch {
            checked: Network.wifiEnabled
            onToggled: Network.enableWifi(checked)
        }
    }

    RowLayout { // Status + rescan
        Layout.fillWidth: true
        Layout.topMargin: -4
        spacing: 8
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
        RippleButton {
            implicitWidth: 34
            implicitHeight: 34
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
    }

    // Full-width divider that turns INTO the scan progress line in place. Both share a
    // fixed 4px slot so toggling scanning on/off never shifts the layout (the old code
    // swapped a 1px separator for a taller progress bar, jumping the header every 6s).
    Item {
        Layout.fillWidth: true
        Layout.topMargin: -8
        Layout.bottomMargin: -8
        Layout.leftMargin: -Appearance.rounding.large
        Layout.rightMargin: -Appearance.rounding.large
        implicitHeight: 4
        Rectangle {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            height: 1
            color: Appearance.colors.colOutline
            visible: !Network.wifiScanning
        }
        StyledIndeterminateProgressBar {
            anchors.fill: parent
            visible: Network.wifiScanning
        }
    }

    StyledText { // Empty / off states
        visible: Network.friendlyWifiNetworks.length === 0
        Layout.fillWidth: true
        Layout.topMargin: 20
        Layout.bottomMargin: 20
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
        Layout.topMargin: -15
        Layout.bottomMargin: -16
        Layout.leftMargin: -Appearance.rounding.large
        Layout.rightMargin: -Appearance.rounding.large

        clip: true
        spacing: 0
        boundsBehavior: Flickable.StopAtBounds

        model: ScriptModel {
            values: Network.friendlyWifiNetworks
        }
        delegate: WifiNetworkItem {
            required property WifiAccessPoint modelData
            wifiNetwork: modelData
            width: ListView.view.width
        }
    }

    ColumnLayout { // Add a hidden network (SSID not broadcast)
        id: hiddenSection
        property bool open: false
        Layout.fillWidth: true
        Layout.topMargin: 4
        visible: Network.wifiEnabled
        spacing: 6

        DialogButton {
            Layout.fillWidth: true
            buttonText: hiddenSection.open ? Translation.tr("Cancel") : Translation.tr("Add hidden network")
            colBackground: Appearance.colors.colLayer4
            colBackgroundHover: Appearance.colors.colLayer4Hover
            colRipple: Appearance.colors.colLayer4Active
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
            placeholderText: Translation.tr("Password (leave empty if open)")
            echoMode: TextInput.Password
            inputMethodHints: Qt.ImhSensitiveData
            onAccepted: if (hiddenSsid.text.length > 0) Network.connectHiddenNetwork(hiddenSsid.text, hiddenPass.text)
        }
        RowLayout {
            visible: hiddenSection.open
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
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

    ColumnLayout { // Scan a Wi-Fi QR with the webcam to connect
        id: qrSection
        Layout.fillWidth: true
        Layout.topMargin: 2
        visible: Network.wifiEnabled
        spacing: 6

        DialogButton {
            Layout.fillWidth: true
            enabled: !qrScanProc.running
            buttonText: qrScanProc.running ? Translation.tr("Point the camera at a Wi-Fi QR…")
                                           : Translation.tr("Scan Wi-Fi QR code")
            colBackground: Appearance.colors.colLayer4
            colBackgroundHover: Appearance.colors.colLayer4Hover
            colRipple: Appearance.colors.colLayer4Active
            onClicked: { qrStatus.text = ""; qrScanProc.running = true; }
        }
        RowLayout {
            visible: qrScanProc.running || qrStatus.text.length > 0
            Layout.fillWidth: true
            spacing: 8
            StyledText {
                id: qrStatus
                Layout.fillWidth: true
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                elide: Text.ElideRight
                text: ""
            }
            DialogButton {
                visible: qrScanProc.running
                buttonText: Translation.tr("Cancel")
                onClicked: qrScanProc.running = false
            }
        }
    }

    ColumnLayout { // Wi-Fi hotspot (share this machine's connection over AP mode)
        id: hotspotSection
        property bool open: false
        property string band: Network.hotspotBand
        Layout.fillWidth: true
        Layout.topMargin: 2
        spacing: 6

        Component.onCompleted: Network.loadHotspotConfig()
        // Keep the band selector in sync with the loaded/saved profile.
        Connections {
            target: Network
            function onHotspotBandChanged() { hotspotSection.band = Network.hotspotBand; }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            DialogButton {
                Layout.fillWidth: true
                buttonText: hotspotSection.open ? Translation.tr("Hide hotspot settings")
                    : Network.hotspotActive ? Translation.tr("Hotspot on · %1 device(s)").arg(Network.hotspotClients)
                    : Translation.tr("Wi-Fi hotspot")
                colBackground: Appearance.colors.colLayer4
                colBackgroundHover: Appearance.colors.colLayer4Hover
                colRipple: Appearance.colors.colLayer4Active
                onClicked: hotspotSection.open = !hotspotSection.open
            }
            StyledSwitch {
                enabled: !Network.hotspotEnabling && (hsSsid.text.length > 0)
                checked: Network.hotspotActive
                onToggled: {
                    if (checked) Network.startHotspot(hsSsid.text, hsPass.text, hotspotSection.band);
                    else Network.stopHotspot();
                }
            }
        }
        MaterialTextField {
            id: hsSsid
            visible: hotspotSection.open
            Layout.fillWidth: true
            placeholderText: Translation.tr("Hotspot name (SSID)")
            text: Network.hotspotSsid
        }
        MaterialTextField {
            id: hsPass
            visible: hotspotSection.open
            Layout.fillWidth: true
            placeholderText: Translation.tr("Password (8+ chars, empty = open)")
            echoMode: TextInput.Password
            inputMethodHints: Qt.ImhSensitiveData
            text: Network.hotspotPassword
        }
        RowLayout { // 2.4 GHz / 5 GHz band selector (locked to client channel on Wi-Fi)
            visible: hotspotSection.open
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
                    colBackground: hotspotSection.band === modelData.val ? Appearance.colors.colPrimary : Appearance.colors.colLayer4
                    colText: hotspotSection.band === modelData.val ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnSurfaceVariant
                    onClicked: hotspotSection.band = modelData.val
                }
            }
        }
        RowLayout { // status + start/stop
            visible: hotspotSection.open
            Layout.fillWidth: true
            spacing: 8
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
            DialogButton {
                enabled: !Network.hotspotEnabling && hsSsid.text.length > 0
                    && (hsPass.text.length === 0 || hsPass.text.length >= 8)
                buttonText: Network.hotspotActive ? Translation.tr("Stop") : Translation.tr("Start")
                onClicked: {
                    if (Network.hotspotActive) Network.stopHotspot();
                    else Network.startHotspot(hsSsid.text, hsPass.text, hotspotSection.band);
                }
            }
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
