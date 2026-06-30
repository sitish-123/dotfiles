import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Quickshell

WindowDialog {
    id: root
    backgroundHeight: 600
    backgroundWidth: 400

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool btEnabled: adapter?.enabled ?? false
    readonly property bool discovering: adapter?.discovering ?? false
    // Which device is expanded, keyed by address — lives here (not in the delegate) so it
    // survives delegates being recycled/reordered as devices appear during discovery.
    property string expandedAddress: ""

    // Start a scan on open (if enabled); stop it when the dialog closes.
    Component.onCompleted: if (root.adapter && root.btEnabled) root.adapter.discovering = true
    Component.onDestruction: if (root.adapter) root.adapter.discovering = false

    RowLayout { // Title + power toggle
        Layout.fillWidth: true
        spacing: 8
        WindowDialogTitle {
            Layout.fillWidth: true
            text: Translation.tr("Bluetooth")
        }
        StyledSwitch {
            checked: root.btEnabled
            onToggled: if (root.adapter) root.adapter.enabled = checked
        }
    }

    RowLayout { // Status + scan
        Layout.fillWidth: true
        Layout.topMargin: -4
        spacing: 8
        StyledText {
            Layout.fillWidth: true
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            elide: Text.ElideRight
            text: !root.btEnabled ? Translation.tr("Bluetooth is off")
                : BluetoothStatus.activeDeviceCount > 0
                    ? Translation.tr("%1 connected").arg(BluetoothStatus.firstActiveDevice?.name ?? Translation.tr("device"))
                : root.discovering ? Translation.tr("Scanning…")
                : Translation.tr("Not connected")
        }
        RippleButton {
            implicitWidth: 34
            implicitHeight: 34
            buttonRadius: Appearance.rounding.full
            enabled: root.btEnabled
            releaseAction: () => { if (root.adapter) root.adapter.discovering = !root.adapter.discovering }
            contentItem: MaterialSymbol {
                id: scanIcon
                anchors.centerIn: parent
                text: "bluetooth_searching"
                iconSize: Appearance.font.pixelSize.larger
                color: root.discovering ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                RotationAnimator on rotation {
                    running: root.discovering
                    loops: Animation.Infinite
                    from: 0; to: 360; duration: 1400
                    onRunningChanged: if (!running) scanIcon.rotation = 0
                }
            }
        }
    }

    // Divider that turns into the scan progress line in place — fixed 4px slot so
    // toggling discovery never shifts the layout (see WifiDialog for the rationale).
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
            visible: !root.discovering
        }
        StyledIndeterminateProgressBar {
            anchors.fill: parent
            visible: root.discovering
        }
    }

    StyledText { // empty / off states
        visible: BluetoothStatus.friendlyDeviceList.length === 0
        Layout.fillWidth: true
        Layout.topMargin: 20
        Layout.bottomMargin: 20
        horizontalAlignment: Text.AlignHCenter
        color: Appearance.colors.colSubtext
        text: !root.btEnabled ? Translation.tr("Turn on Bluetooth to see devices")
            : root.discovering ? Translation.tr("Scanning for devices…")
            : Translation.tr("No devices found")
    }

    StyledListView {
        visible: BluetoothStatus.friendlyDeviceList.length > 0
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.topMargin: -15
        Layout.bottomMargin: -16
        Layout.leftMargin: -Appearance.rounding.large
        Layout.rightMargin: -Appearance.rounding.large

        clip: true
        spacing: 0
        animateAppearance: false

        model: ScriptModel {
            values: BluetoothStatus.friendlyDeviceList
        }
        delegate: BluetoothDeviceItem {
            required property BluetoothDevice modelData
            device: modelData
            expanded: root.expandedAddress.length > 0 && root.expandedAddress === (modelData?.address ?? "")
            onToggleExpand: {
                const a = modelData?.address ?? "";
                root.expandedAddress = (root.expandedAddress === a) ? "" : a;
            }
            anchors {
                left: parent?.left
                right: parent?.right
            }
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
