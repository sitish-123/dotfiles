import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "../ii/sidebarRight/bluetoothDevices" as Bt
import Quickshell.Bluetooth

ContentPage {
    forceWidth: true

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool btEnabled: adapter?.enabled ?? false
    readonly property bool discovering: adapter?.discovering ?? false

    Component.onCompleted: if (adapter && btEnabled) adapter.discovering = true
    Component.onDestruction: if (adapter) adapter.discovering = false

    ContentSection {
        icon: "bluetooth"
        title: Translation.tr("Bluetooth")

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    color: Appearance.colors.colOnSurface
                    text: btEnabled ? Translation.tr("On") : Translation.tr("Off")
                }
                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    text: !btEnabled ? Translation.tr("Bluetooth is off")
                        : BluetoothStatus.activeDeviceCount > 0
                            ? Translation.tr("%1 connected").arg(BluetoothStatus.firstActiveDevice?.name ?? Translation.tr("device"))
                        : discovering ? Translation.tr("Scanning…")
                        : Translation.tr("Not connected")
                }
            }
            RippleButton {
                implicitWidth: 34; implicitHeight: 34
                buttonRadius: Appearance.rounding.full
                enabled: btEnabled
                releaseAction: () => { if (adapter) adapter.discovering = !adapter.discovering }
                contentItem: MaterialSymbol {
                    id: scanIcon
                    anchors.centerIn: parent
                    text: "bluetooth_searching"
                    iconSize: Appearance.font.pixelSize.larger
                    color: discovering ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                    RotationAnimator on rotation {
                        running: discovering
                        loops: Animation.Infinite
                        from: 0; to: 360; duration: 1400
                        onRunningChanged: if (!running) scanIcon.rotation = 0
                    }
                }
            }
            StyledSwitch {
                checked: btEnabled
                onToggled: if (adapter) adapter.enabled = checked
            }
        }

        StyledText {
            visible: BluetoothStatus.friendlyDeviceList.length === 0
            Layout.fillWidth: true
            Layout.topMargin: 8
            horizontalAlignment: Text.AlignHCenter
            color: Appearance.colors.colSubtext
            text: !btEnabled ? Translation.tr("Turn on Bluetooth to see devices")
                : discovering ? Translation.tr("Scanning for devices…")
                : Translation.tr("No devices found")
        }

        Repeater {
            model: ScriptModel { values: BluetoothStatus.friendlyDeviceList }
            delegate: Bt.BluetoothDeviceItem {
                required property BluetoothDevice modelData
                device: modelData
                Layout.fillWidth: true
            }
        }
    }
}
