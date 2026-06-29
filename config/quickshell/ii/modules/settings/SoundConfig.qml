import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Quickshell.Services.Pipewire

ContentPage {
    forceWidth: true

    // Reusable volume row + device list, parameterized for output vs input.
    component AudioSection: ContentSection {
        property var node: null
        property var devices: []
        property bool isInput: false
        property var setDefault: function(n) {}
        property var defaultId: null

        RowLayout { // volume + mute
            Layout.fillWidth: true
            spacing: 10
            RippleButton {
                implicitWidth: 36; implicitHeight: 36
                buttonRadius: Appearance.rounding.full
                releaseAction: () => { if (node?.audio) node.audio.muted = !node.audio.muted }
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: node?.audio?.muted ? (isInput ? "mic_off" : "volume_off")
                        : (isInput ? "mic" : "volume_up")
                    iconSize: Appearance.font.pixelSize.larger
                    color: node?.audio?.muted ? Appearance.colors.colSubtext : Appearance.colors.colOnSurfaceVariant
                }
            }
            StyledSlider {
                Layout.fillWidth: true
                from: 0; to: 1
                value: node?.audio?.volume ?? 0
                onMoved: if (node?.audio) node.audio.volume = value
            }
            StyledText {
                Layout.minimumWidth: 38
                horizontalAlignment: Text.AlignRight
                color: Appearance.colors.colOnSurface
                text: `${Math.round((node?.audio?.volume ?? 0) * 100)}%`
            }
        }

        StyledText {
            Layout.topMargin: 4
            text: Translation.tr("Device")
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smaller
        }
        Repeater {
            model: ScriptModel { values: devices }
            delegate: RippleButton {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 40
                buttonRadius: Appearance.rounding.small
                toggled: modelData.id === defaultId
                colBackgroundToggled: Appearance.colors.colSecondaryContainer
                onClicked: setDefault(modelData)
                contentItem: RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10
                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        color: Appearance.colors.colOnSurface
                        text: modelData.description ?? modelData.name ?? Translation.tr("Unknown")
                        textFormat: Text.PlainText
                    }
                    MaterialSymbol {
                        visible: modelData.id === defaultId
                        text: "check"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colPrimary
                    }
                }
            }
        }
    }

    AudioSection {
        icon: "volume_up"
        title: Translation.tr("Output")
        node: Audio.sink
        devices: Audio.outputDevices
        isInput: false
        defaultId: Pipewire.defaultAudioSink?.id ?? null
        setDefault: function(n) { Audio.setDefaultSink(n); }
    }

    AudioSection {
        icon: "mic"
        title: Translation.tr("Input")
        node: Audio.source
        devices: Audio.inputDevices
        isInput: true
        defaultId: Pipewire.defaultAudioSource?.id ?? null
        setDefault: function(n) { Audio.setDefaultSource(n); }
    }
}
