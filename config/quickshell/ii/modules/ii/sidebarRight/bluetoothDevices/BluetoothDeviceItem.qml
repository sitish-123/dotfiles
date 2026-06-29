import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

DialogListItem {
    id: root
    required property var device
    readonly property bool isConnected: device?.connected ?? false
    readonly property bool isPaired: device?.paired ?? false
    readonly property bool isBusy: (device?.pairing ?? false)
    property bool expanded: false  // item-local (device is a native object, can't add props)
    pointingHandCursor: true

    active: root.expanded || root.isConnected
    onClicked: root.expanded = !root.expanded

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
                text: Icons.getBluetoothDeviceMaterialSymbol(root.device?.icon || "")
                color: root.isConnected ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                StyledText {
                    Layout.fillWidth: true
                    color: root.isConnected ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                    elide: Text.ElideRight
                    text: root.device?.name || Translation.tr("Unknown device")
                    textFormat: Text.PlainText
                }
                StyledText { // status • battery
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                    text: {
                        const parts = [];
                        if (root.isBusy) parts.push(Translation.tr("Connecting…"));
                        else if (root.isConnected) parts.push(Translation.tr("Connected"));
                        else if (root.isPaired) parts.push(Translation.tr("Paired"));
                        else parts.push(Translation.tr("Available"));
                        if (root.device?.batteryAvailable)
                            parts.push(`${Math.round((root.device?.battery ?? 0) * 100)}%`);
                        return parts.join("  ·  ");
                    }
                }
            }
            MaterialSymbol { // battery glyph when connected
                visible: root.isConnected && (root.device?.batteryAvailable ?? false)
                text: {
                    const b = (root.device?.battery ?? 0) * 100;
                    return b > 90 ? "battery_full" : b > 60 ? "battery_5_bar" : b > 35 ? "battery_3_bar"
                         : b > 15 ? "battery_2_bar" : "battery_alert";
                }
                iconSize: Appearance.font.pixelSize.normal
                color: ((root.device?.battery ?? 0) * 100) <= 15 ? Appearance.colors.colError : Appearance.colors.colSubtext
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

                Rectangle { // Details card
                    Layout.fillWidth: true
                    radius: Appearance.rounding.small
                    color: Appearance.m3colors.m3surfaceContainerHighest
                    implicitHeight: detailsCol.implicitHeight + 24

                    ColumnLayout {
                        id: detailsCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                        spacing: 7

                        Repeater {
                            model: {
                                const rows = [];
                                if (root.device?.address) rows.push({ k: Translation.tr("Address"), v: root.device.address });
                                if (root.device?.batteryAvailable) rows.push({ k: Translation.tr("Battery"), v: `${Math.round((root.device?.battery ?? 0) * 100)}%` });
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
                        Rectangle {
                            visible: root.isPaired
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: Appearance.colors.colOutlineVariant ?? Appearance.colors.colSubtext
                            opacity: 0.4
                        }
                        RowLayout { // Auto-connect (trusted) — fixes "sometimes auto connects"
                            visible: root.isPaired
                            Layout.fillWidth: true
                            StyledText {
                                Layout.fillWidth: true
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnSurfaceVariant
                                text: Translation.tr("Connect automatically")
                            }
                            StyledSwitch {
                                checked: root.device?.trusted ?? false
                                onToggled: if (root.device) root.device.trusted = checked
                            }
                        }
                    }
                }

                RowLayout { // One clean action row
                    Layout.fillWidth: true
                    spacing: 8

                    DialogButton {
                        visible: root.isPaired
                        Layout.fillWidth: true
                        buttonText: Translation.tr("Forget")
                        colBackground: Appearance.colors.colError
                        colBackgroundHover: Appearance.colors.colErrorHover
                        colRipple: Appearance.colors.colErrorActive
                        colText: Appearance.colors.colOnError
                        onClicked: root.device?.forget()
                    }
                    DialogButton { // primary
                        Layout.fillWidth: true
                        enabled: !root.isBusy
                        buttonText: root.isBusy ? Translation.tr("Connecting…")
                            : root.isConnected ? Translation.tr("Disconnect")
                            : root.isPaired ? Translation.tr("Connect")
                            : Translation.tr("Pair")
                        onClicked: {
                            if (root.isConnected) root.device?.disconnect();
                            else if (root.isPaired) root.device?.connect();
                            else root.device?.pair();
                        }
                    }
                }
            }
        }
    }
}
