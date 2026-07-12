import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import Quickshell
import Quickshell.Bluetooth

ContentPage {
    id: page
    forceWidth: true

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool btEnabled: adapter?.enabled ?? false
    readonly property bool discovering: adapter?.discovering ?? false

    Component.onCompleted: if (adapter && btEnabled) adapter.discovering = true
    Component.onDestruction: if (adapter) adapter.discovering = false

    // Auto-stop discovery after a window so the scan spinner doesn't run forever while
    // the page is open (paired/known devices show instantly regardless; the scan button
    // re-arms it). Restarts whenever discovering is toggled back on.
    Timer {
        interval: 30000
        running: page.discovering
        repeat: false
        onTriggered: if (page.adapter) page.adapter.discovering = false
    }

    ContentSection {
        icon: "bluetooth"
        title: Translation.tr("Bluetooth")

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText { color: Appearance.colors.colOnSurface; text: page.btEnabled ? Translation.tr("On") : Translation.tr("Off") }
                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    text: !page.btEnabled ? Translation.tr("Bluetooth is off")
                        : BluetoothStatus.activeDeviceCount > 0 ? Translation.tr("%1 connected").arg(BluetoothStatus.firstActiveDevice?.name ?? Translation.tr("device"))
                        : page.discovering ? Translation.tr("Scanning…") : Translation.tr("Not connected")
                }
            }
            RippleButton {
                implicitWidth: 34; implicitHeight: 34
                buttonRadius: Appearance.rounding.full
                enabled: page.btEnabled
                releaseAction: () => { if (page.adapter) page.adapter.discovering = !page.adapter.discovering }
                contentItem: MaterialSymbol {
                    id: scanIcon
                    anchors.centerIn: parent
                    text: "bluetooth_searching"; iconSize: Appearance.font.pixelSize.larger
                    color: page.discovering ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                    RotationAnimator on rotation { running: page.discovering; loops: Animation.Infinite; from: 0; to: 360; duration: 1400; onRunningChanged: if (!running) scanIcon.rotation = 0 }
                }
            }
            StyledSwitch { checked: page.btEnabled; onToggled: if (page.adapter) page.adapter.enabled = checked }
        }

        StyledText {
            visible: BluetoothStatus.friendlyDeviceList.length === 0
            Layout.fillWidth: true; Layout.topMargin: 8
            horizontalAlignment: Text.AlignHCenter
            color: Appearance.colors.colSubtext
            text: !page.btEnabled ? Translation.tr("Turn on Bluetooth to see devices")
                : page.discovering ? Translation.tr("Scanning for devices…") : Translation.tr("No devices found")
        }

        Repeater {
            model: ScriptModel { objectProp: "address"; values: BluetoothStatus.friendlyDeviceList }
            delegate: ColumnLayout {
                id: drow
                required property var modelData
                readonly property bool isConnected: modelData?.connected ?? false
                readonly property bool isPaired: modelData?.paired ?? false
                readonly property bool isBusy: modelData?.pairing ?? false
                // Recover from a hung BlueZ pairing after 30s (see the sidebar item) so
                // the row doesn't sit on "Connecting…" forever.
                property bool pairTimedOut: false
                onIsBusyChanged: if (!drow.isBusy) drow.pairTimedOut = false
                Timer {
                    interval: 30000; repeat: false
                    running: drow.isBusy && !drow.pairTimedOut
                    onTriggered: drow.pairTimedOut = true
                }
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    MaterialSymbol {
                        text: Icons.getBluetoothDeviceMaterialSymbol(drow.modelData?.icon || "")
                        iconSize: Appearance.font.pixelSize.larger
                        color: drow.isConnected ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        StyledText {
                            Layout.fillWidth: true; elide: Text.ElideRight
                            color: drow.isConnected ? Appearance.colors.colPrimary : Appearance.colors.colOnSurface
                            text: drow.modelData?.name || Translation.tr("Unknown device"); textFormat: Text.PlainText
                        }
                        StyledText {
                            Layout.fillWidth: true; elide: Text.ElideRight
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                            text: {
                                const p = [];
                                if (drow.pairTimedOut) p.push(Translation.tr("Pairing timed out"));
                                else if (drow.isBusy) p.push(Translation.tr("Connecting…"));
                                else if (drow.isConnected) p.push(Translation.tr("Connected"));
                                else if (drow.isPaired) p.push(Translation.tr("Paired"));
                                else p.push(Translation.tr("Available"));
                                if (drow.modelData?.batteryAvailable) p.push(`${Math.round((drow.modelData?.battery ?? 0) * 100)}%`);
                                return p.join("  ·  ");
                            }
                        }
                    }
                    DialogButton {
                        visible: drow.isPaired
                        buttonText: Translation.tr("Forget")
                        colBackground: Appearance.colors.colError; colBackgroundHover: Appearance.colors.colErrorHover; colRipple: Appearance.colors.colErrorActive; colText: Appearance.colors.colOnError
                        onClicked: drow.modelData?.forget()
                    }
                    DialogButton {
                        buttonText: drow.isConnected ? Translation.tr("Disconnect") : drow.isPaired ? Translation.tr("Connect") : Translation.tr("Pair")
                        onClicked: {
                            drow.pairTimedOut = false;
                            if (drow.isConnected) drow.modelData?.disconnect();
                            else if (drow.isPaired) drow.modelData?.connect();
                            else drow.modelData?.pair();
                        }
                    }
                }
                RowLayout {
                    visible: drow.isPaired
                    Layout.fillWidth: true
                    Layout.leftMargin: 34
                    StyledText {
                        Layout.fillWidth: true
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                        text: Translation.tr("Connect automatically")
                    }
                    StyledSwitch { checked: drow.modelData?.trusted ?? false; onToggled: if (drow.modelData) drow.modelData.trusted = checked }
                }
            }
        }
    }
}
