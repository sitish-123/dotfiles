import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Quickshell

ContentPage {
    forceWidth: true

    ContentSection {
        icon: "brightness_6"
        title: Translation.tr("Brightness")

        Repeater {
            model: Quickshell.screens
            delegate: ColumnLayout {
                required property var modelData
                readonly property var bm: Brightness.getMonitorForScreen(modelData)
                Layout.fillWidth: true
                spacing: 2
                visible: bm !== null

                StyledText {
                    text: modelData.name + (modelData.model ? `  (${modelData.model})` : "")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    MaterialSymbol {
                        text: "brightness_low"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                    StyledSlider {
                        Layout.fillWidth: true
                        from: 0.01; to: 1
                        value: parent.parent.bm?.brightness ?? 1
                        onMoved: if (parent.parent.bm) parent.parent.bm.setBrightness(value)
                    }
                    StyledText {
                        Layout.minimumWidth: 38
                        horizontalAlignment: Text.AlignRight
                        color: Appearance.colors.colOnSurface
                        text: `${Math.round((parent.parent.bm?.brightness ?? 0) * 100)}%`
                    }
                }
            }
        }
    }

    ContentSection {
        icon: "monitor"
        title: Translation.tr("Displays")

        Repeater {
            model: Quickshell.screens
            delegate: ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 1
                StyledText {
                    color: Appearance.colors.colOnSurface
                    text: modelData.name
                }
                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    text: {
                        const parts = [`${modelData.width}×${modelData.height}`];
                        if (modelData.model) parts.push(modelData.model);
                        return parts.join("  ·  ");
                    }
                }
            }
        }
    }
}
