import qs
import qs.services
import qs.services.network
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

WindowDialog {
    id: root
    backgroundHeight: 600

    // Scan on open so the list is fresh, then keep refreshing while open.
    Component.onCompleted: if (Network.wifiEnabled) Network.rescanWifi()
    Timer {
        interval: 6000
        running: Network.wifiEnabled
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

    WindowDialogSeparator {
        visible: !Network.wifiScanning
    }
    StyledIndeterminateProgressBar {
        visible: Network.wifiScanning
        Layout.fillWidth: true
        Layout.topMargin: -8
        Layout.bottomMargin: -8
        Layout.leftMargin: -Appearance.rounding.large
        Layout.rightMargin: -Appearance.rounding.large
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

    WindowDialogSeparator {}
    WindowDialogButtonRow {
        Item { Layout.fillWidth: true }
        DialogButton {
            buttonText: Translation.tr("Done")
            onClicked: root.dismiss()
        }
    }
}
