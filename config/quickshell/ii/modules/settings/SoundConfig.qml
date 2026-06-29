import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Quickshell
import Quickshell.Services.Pipewire

ContentPage {
    forceWidth: true

    ContentSection {
        icon: "volume_up"
        title: Translation.tr("Output")

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            RippleButton {
                implicitWidth: 36; implicitHeight: 36
                buttonRadius: Appearance.rounding.full
                releaseAction: () => { if (Audio.sink?.audio) Audio.sink.audio.muted = !Audio.sink.audio.muted }
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: Audio.sink?.audio?.muted ? "volume_off" : "volume_up"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Audio.sink?.audio?.muted ? Appearance.colors.colSubtext : Appearance.colors.colOnSurfaceVariant
                }
            }
            StyledSlider {
                Layout.fillWidth: true
                from: 0; to: 1
                value: Audio.sink?.audio?.volume ?? 0
                onMoved: if (Audio.sink?.audio) Audio.sink.audio.volume = value
            }
            StyledText { Layout.minimumWidth: 38; horizontalAlignment: Text.AlignRight; color: Appearance.colors.colOnSurface; text: `${Math.round((Audio.sink?.audio?.volume ?? 0) * 100)}%` }
        }

        StyledText { Layout.topMargin: 4; text: Translation.tr("Device"); color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smaller }
        Repeater {
            model: ScriptModel { values: Audio.outputDevices }
            delegate: RowLayout {
                required property var modelData
                readonly property bool isDefault: modelData.id === (Pipewire.defaultAudioSink?.id ?? -1)
                Layout.fillWidth: true
                spacing: 10
                MaterialSymbol { text: parent.isDefault ? "check_circle" : "speaker"; iconSize: Appearance.font.pixelSize.larger; color: parent.isDefault ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant }
                StyledText { Layout.fillWidth: true; elide: Text.ElideRight; color: Appearance.colors.colOnSurface; text: modelData.description ?? modelData.name ?? Translation.tr("Unknown"); textFormat: Text.PlainText }
                DialogButton { visible: !parent.isDefault; buttonText: Translation.tr("Use"); onClicked: Audio.setDefaultSink(modelData) }
            }
        }
    }

    ContentSection {
        icon: "mic"
        title: Translation.tr("Input")

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            RippleButton {
                implicitWidth: 36; implicitHeight: 36
                buttonRadius: Appearance.rounding.full
                releaseAction: () => { if (Audio.source?.audio) Audio.source.audio.muted = !Audio.source.audio.muted }
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: Audio.source?.audio?.muted ? "mic_off" : "mic"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Audio.source?.audio?.muted ? Appearance.colors.colSubtext : Appearance.colors.colOnSurfaceVariant
                }
            }
            StyledSlider {
                Layout.fillWidth: true
                from: 0; to: 1
                value: Audio.source?.audio?.volume ?? 0
                onMoved: if (Audio.source?.audio) Audio.source.audio.volume = value
            }
            StyledText { Layout.minimumWidth: 38; horizontalAlignment: Text.AlignRight; color: Appearance.colors.colOnSurface; text: `${Math.round((Audio.source?.audio?.volume ?? 0) * 100)}%` }
        }

        StyledText { Layout.topMargin: 4; text: Translation.tr("Device"); color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smaller }
        Repeater {
            model: ScriptModel { values: Audio.inputDevices }
            delegate: RowLayout {
                required property var modelData
                readonly property bool isDefault: modelData.id === (Pipewire.defaultAudioSource?.id ?? -1)
                Layout.fillWidth: true
                spacing: 10
                MaterialSymbol { text: parent.isDefault ? "check_circle" : "mic"; iconSize: Appearance.font.pixelSize.larger; color: parent.isDefault ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant }
                StyledText { Layout.fillWidth: true; elide: Text.ElideRight; color: Appearance.colors.colOnSurface; text: modelData.description ?? modelData.name ?? Translation.tr("Unknown"); textFormat: Text.PlainText }
                DialogButton { visible: !parent.isDefault; buttonText: Translation.tr("Use"); onClicked: Audio.setDefaultSource(modelData) }
            }
        }
    }
}
