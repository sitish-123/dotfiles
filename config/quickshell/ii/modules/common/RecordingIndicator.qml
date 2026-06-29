import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Always-on, top-centered pill shown whenever a recording or replay buffer is
// active — so it's never a mystery whether the screen is being captured.
// Click the buttons to pause/resume, save the replay, or stop.
PanelWindow {
    id: root
    visible: Recording.anyActive
    color: "transparent"
    WlrLayershell.namespace: "quickshell:recordingIndicator"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    anchors.top: true
    margins.top: 6
    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight + 2

    readonly property color recColor: "#e53935"

    Rectangle {
        id: pill
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        implicitWidth: row.implicitWidth + 24
        implicitHeight: 34
        radius: height / 2
        color: Appearance.colors.colLayer0
        border.width: 1
        border.color: Recording.paused ? Appearance.colors.colSubtext : root.recColor

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 8

            Rectangle { // pulsing dot
                Layout.alignment: Qt.AlignVCenter
                visible: !Recording.paused
                implicitWidth: 11; implicitHeight: 11; radius: height / 2
                color: Recording.replay ? Appearance.colors.colPrimary : root.recColor
                SequentialAnimation on opacity {
                    running: root.visible && !Recording.paused
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 0.25; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.25; to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                }
            }
            MaterialSymbol {
                visible: Recording.paused
                text: "pause"; iconSize: 18
                color: Appearance.colors.colSubtext
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                color: Appearance.colors.colOnLayer0
                font.pixelSize: Appearance.font.pixelSize.small
                text: (Recording.replay ? Translation.tr("Replay")
                        : Recording.paused ? Translation.tr("Paused")
                        : Translation.tr("REC"))
                    + "  " + Recording.fmt(Recording.elapsed)
            }

            IndicatorButton { // pause / resume (normal recording only)
                visible: Recording.active
                symbolText: Recording.paused ? "play_arrow" : "pause"
                onClicked: Recording.togglePause()
            }
            IndicatorButton { // save the replay buffer
                visible: Recording.replay
                symbolText: "save"
                onClicked: Recording.saveReplay()
            }
            IndicatorButton { // stop
                symbolText: "stop"
                danger: true
                onClicked: Recording.stop()
            }
        }
    }

    component IndicatorButton: RippleButton {
        id: ib
        required property string symbolText
        property bool danger: false
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 26; implicitHeight: 26
        buttonRadius: height / 2
        colBackground: ib.danger ? Appearance.colors.colError : Appearance.colors.colLayer2
        colBackgroundHover: ib.danger ? Appearance.colors.colError : Appearance.colors.colLayer2Hover
        colRipple: Appearance.colors.colLayer2Active
        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            text: ib.symbolText
            iconSize: 16
            color: ib.danger ? Appearance.colors.colOnError : Appearance.colors.colOnLayer2
        }
    }
}
