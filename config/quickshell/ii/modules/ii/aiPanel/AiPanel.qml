import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Pill switcher for the AI panel (replaces the old left sidebar). The Gemini/ChatGPT/
// Claude chromium --app windows float docked-left on the "ai" special workspace (see
// custom/rules.lua + ai-sidebar.sh). This layer panel sits in the top strip and is shown
// only while that special workspace is active; clicking a pill raises that window.
Scope {
    id: root
    property bool aiActive: false
    property string current: "Gemini"
    readonly property string iconDir: (Quickshell.env("HOME") ?? "") + "/.local/share/icons/ii-webapps/"
    readonly property var providers: [
        { "name": "Gemini",  "icon": "gemini.svg" },
        { "name": "ChatGPT", "icon": "chatgpt.svg" },
        { "name": "Claude",  "icon": "claude.svg" }
    ]

    function raise(name) {
        root.current = name;
        Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "class:^(" + name + ")$"]);
    }

    // Track whether the "ai" special workspace is showing (Hyprland fires activespecial /
    // activespecialv2 with the special workspace name, or empty when it's hidden).
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activespecial" || event.name === "activespecialv2")
                root.aiActive = (event.data ?? "").includes("special:ai");
        }
    }

    PanelWindow {
        id: panelWindow
        visible: root.aiActive
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell:aiPanelPills"
        WlrLayershell.layer: WlrLayer.Overlay
        anchors { top: true; left: true }
        margins { top: 12; left: 12 }
        implicitWidth: Math.round(screen.width * 0.32)
        implicitHeight: 46

        Rectangle {
            anchors.fill: parent
            radius: Appearance.rounding.full
            color: Appearance.colors.colLayer0

            RowLayout {
                anchors.centerIn: parent
                spacing: 6

                Repeater {
                    model: root.providers
                    delegate: RippleButton {
                        required property var modelData
                        implicitHeight: 32
                        leftPadding: 12
                        rightPadding: 14
                        buttonRadius: Appearance.rounding.full
                        toggled: root.current === modelData.name
                        colBackgroundToggled: Appearance.colors.colSecondaryContainer
                        colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
                        onClicked: root.raise(modelData.name)
                        contentItem: RowLayout {
                            spacing: 7
                            Image {
                                source: "file://" + root.iconDir + modelData.icon
                                sourceSize.width: 18; sourceSize.height: 18
                                Layout.preferredWidth: 18; Layout.preferredHeight: 18
                                fillMode: Image.PreserveAspectFit
                            }
                            StyledText {
                                text: modelData.name
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: root.current === modelData.name ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer0
                            }
                        }
                    }
                }
            }
        }
    }
}
