import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.layershell 1.0 as LayerShell
import QtWebEngine

// Floating layer-shell sidebar (like the old Quickshell one). The SURFACE is inset via
// LayerShellQt margins in main.cpp so it floats; the panel is rounded + translucent so
// Hyprland blur frosts it (corners stay sharp via ignore_alpha). A fullscreen catcher
// layer below it dismisses on a real click outside (not on hover — follow_mouse is on).
Window {
    id: win
    visible: Controller.shown
    width: 500
    color: "transparent"

    LayerShell.Window.anchors: LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.exclusionZone: 0
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand
    LayerShell.Window.activateOnShow: true
    LayerShell.Window.scope: "ai-sidebar"

    readonly property var tabs: [
        { "name": "Gemini",  "url": "https://gemini.google.com/app" },
        { "name": "ChatGPT", "url": "https://chatgpt.com/" },
        { "name": "Claude",  "url": "https://claude.ai/new" }
    ]
    property int current: 0

    // Fullscreen transparent catcher (one layer below the sidebar) — a real click anywhere
    // outside the panel dismisses it. follow_mouse=1 means we can't use focus loss (that
    // fires on hover), so this is the reliable "tap outside to close".
    Window {
        id: catcher
        visible: Controller.shown
        color: "transparent"
        LayerShell.Window.anchors: LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight | LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom
        LayerShell.Window.layer: LayerShell.Window.LayerTop
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
        LayerShell.Window.scope: "ai-sidebar-catcher"
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onPressed: Controller.shown = false
        }
    }

    WebEngineProfile {
        id: aiProfile
        storageName: "ai-sidebar"        // persists cookies/login under ~/.local/share
        offTheRecord: false
    }

    Rectangle {                          // rounded translucent panel (surface already inset)
        id: panel
        anchors.fill: parent
        radius: 18
        color: Qt.rgba(0.07, 0.07, 0.09, 0.55)   // translucent -> Hyprland blur frosts it
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.06)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            RowLayout {                  // pill switcher
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: win.tabs
                    delegate: Button {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        text: modelData.name
                        checkable: true
                        checked: win.current === index
                        onClicked: win.current = index
                        background: Rectangle {
                            radius: 17
                            color: parent.checked ? Qt.rgba(1, 1, 1, 0.16)
                                 : parent.hovered ? Qt.rgba(1, 1, 1, 0.08)
                                 : Qt.rgba(1, 1, 1, 0.03)
                        }
                        contentItem: Text {
                            text: parent.text
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            color: "white"
                            opacity: parent.checked ? 1 : 0.7
                        }
                    }
                }
            }

            Rectangle {                  // rounded container for the web views
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 12
                color: "#1b1b22"
                clip: true
                StackLayout {
                    anchors.fill: parent
                    currentIndex: win.current
                    Repeater {
                        model: win.tabs
                        delegate: Item {
                            required property var modelData
                            WebEngineView {
                                id: view
                                anchors.fill: parent
                                profile: aiProfile
                                url: parent.modelData.url
                                backgroundColor: "#1b1b22"   // opaque: no blank/blur-through, no flash
                                onLoadingChanged: (req) => {
                                    if (req.status === WebEngineView.LoadStartedStatus) cover.opacity = 1;
                                    else if (req.status === WebEngineView.LoadSucceededStatus
                                          || req.status === WebEngineView.LoadFailedStatus) cover.opacity = 0;
                                }
                            }
                            Rectangle {
                                id: cover
                                anchors.fill: parent
                                color: "#1b1b22"
                                opacity: 1
                                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                                BusyIndicator { anchors.centerIn: parent; running: cover.opacity > 0.5 }
                            }
                        }
                    }
                }
            }
        }
    }
}
