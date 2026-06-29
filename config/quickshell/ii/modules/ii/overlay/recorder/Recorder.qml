pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.overlay

StyledOverlayWidget {
    id: root
    minimumWidth: 310
    minimumHeight: 130

    // Capture (grim / region freeze / recorder) grabs the whole screen including
    // this panel. Close it first, then act once it's fully gone, so the overlay
    // never ends up in the screenshot/recording.
    Timer {
        id: actionTimer
        interval: 320
        property var pending: null
        onTriggered: { if (pending) { pending(); pending = null; } }
    }
    function runAfterClose(fn) {
        GlobalStates.overlayOpen = false;
        actionTimer.pending = fn;
        actionTimer.restart();
    }

    contentItem: OverlayBackground {
        id: contentItem
        radius: root.contentRadius
        property real padding: 8
        ColumnLayout {
            id: contentColumn
            anchors.centerIn: parent
            spacing: 10

            Row {
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                spacing: 10

                BigRecorderButton {
                    materialSymbol: "screenshot_region"
                    name: "Screenshot region"
                    onClicked: root.runAfterClose(() => Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "region", "screenshot"]))
                }

                BigRecorderButton {
                    materialSymbol: "photo_camera"
                    name: "Screenshot"
                    onClicked: root.runAfterClose(() => Quickshell.execDetached(["bash", "-c", "grim - | wl-copy"]))
                }

                BigRecorderButton {
                    materialSymbol: "screen_record"
                    name: "Record region"
                    onClicked: root.runAfterClose(() => Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "region", "recordWithSound"]))
                }

                BigRecorderButton {
                    materialSymbol: "capture"
                    name: "Record screen"
                    onClicked: root.runAfterClose(() => Quickshell.execDetached([Directories.recordScriptPath, "--fullscreen", "--audio", Config.options.screenRecord.audio]))
                }
            }

            // Audio source for recordings (region "record" stays silent; these apply to
            // "record region with sound" and "record screen").
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8
                Repeater {
                    model: [
                        { mode: "none",   icon: "volume_off", label: "No audio" },
                        { mode: "system", icon: "volume_up",  label: "System audio" },
                        { mode: "mic",    icon: "mic",        label: "Microphone" },
                        { mode: "both",   icon: "graphic_eq", label: "System + mic" }
                    ]
                    delegate: RippleButton {
                        required property var modelData
                        readonly property bool sel: Config.options.screenRecord.audio === modelData.mode
                        implicitWidth: 42
                        implicitHeight: 34
                        buttonRadius: height / 2
                        colBackground: sel ? Appearance.colors.colPrimary : Appearance.colors.colLayer3
                        colBackgroundHover: sel ? Appearance.colors.colPrimary : Appearance.colors.colLayer3Hover
                        colRipple: Appearance.colors.colLayer3Active
                        onClicked: Config.options.screenRecord.audio = modelData.mode
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: modelData.icon
                            iconSize: 20
                            color: sel ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer3
                        }
                        StyledToolTip { text: modelData.label }
                    }
                }
            }

            // Quality preset (gpu-screen-recorder -q). Ultra = highest bitrate.
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8
                Repeater {
                    model: [
                        { v: "medium",    label: "Med" },
                        { v: "high",      label: "High" },
                        { v: "very_high", label: "V.High" },
                        { v: "ultra",     label: "Ultra" }
                    ]
                    delegate: TextChip {
                        required property var modelData
                        label: modelData.label
                        sel: Config.options.screenRecord.quality === modelData.v
                        onClicked: Config.options.screenRecord.quality = modelData.v
                    }
                }
            }

            // Framerate
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8
                Repeater {
                    model: ["30", "60", "120", "144"]
                    delegate: TextChip {
                        required property var modelData
                        label: modelData
                        sel: Config.options.screenRecord.fps === modelData
                        onClicked: Config.options.screenRecord.fps = modelData
                    }
                }
            }

            RippleButton {
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                Layout.fillWidth: false
                buttonRadius: height / 2
                colBackground: Appearance.colors.colLayer3
                colBackgroundHover: Appearance.colors.colLayer3Hover
                colRipple: Appearance.colors.colLayer3Active
                onClicked: {
                    GlobalStates.overlayOpen = false;
                    Qt.openUrlExternally(`file://${Config.options.screenRecord.savePath}`);
                }
                contentItem: Row {
                    anchors.centerIn: parent
                    spacing: 6
                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "animated_images"
                        iconSize: 20
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Translation.tr("Open recordings folder")
                    }
                }
            }
        }
    }

    component TextChip: RippleButton {
        id: chip
        property bool sel: false
        property string label: ""
        implicitWidth: chipText.implicitWidth + 22
        implicitHeight: 30
        buttonRadius: height / 2
        colBackground: sel ? Appearance.colors.colPrimary : Appearance.colors.colLayer3
        colBackgroundHover: sel ? Appearance.colors.colPrimary : Appearance.colors.colLayer3Hover
        colRipple: Appearance.colors.colLayer3Active
        contentItem: StyledText {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: chip.sel ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer3
        }
    }

    component BigRecorderButton: RippleButton {
        id: bigButton
        required property string materialSymbol
        required property string name
        implicitHeight: 66
        implicitWidth: 66
        buttonRadius: height / 2

        colBackground: Appearance.colors.colLayer3
        colBackgroundHover: Appearance.colors.colLayer3Hover
        colRipple: Appearance.colors.colLayer3Active

        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: bigButton.materialSymbol
            iconSize: 28
        }

        StyledToolTip {
            text: bigButton.name
        }
    }
}
