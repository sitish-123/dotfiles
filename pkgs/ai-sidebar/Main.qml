import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.layershell 1.0 as LayerShell
import QtWebEngine

// Floating layer-shell sidebar (like the old Quickshell one). The SURFACE stays mapped the
// WHOLE time — to "close" we slide it off-screen via LayerShell margins rather than hiding it.
// Hiding destroyed the Wayland surface, and QtWebEngine would then come back BLANK/black until
// you tapped it (it never submitted a frame for the fresh surface). Keeping the surface mapped
// means the painted web frame is always there, so reopening is instant.
Window {
    id: win
    visible: true                        // ALWAYS mapped; visibility is controlled by margins below
    width: 460                           // match the right sidebar (Appearance.sizes.sidebarWidth)
    color: "transparent"

    readonly property int gap: 8         // float gap on the anchored edges (top/left/bottom)

    LayerShell.Window.anchors: LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.exclusionZone: 0
    // Open: gap on top/left/bottom. Closed: large negative left margin parks the whole panel
    // off the left edge of the screen (surface stays alive, just not visible).
    LayerShell.Window.margins: ({
        "left":   Controller.shown ? gap : -(win.width + 80),
        "top":    gap,
        "right":  0,
        "bottom": gap
    })
    LayerShell.Window.keyboardInteractivity: Controller.shown ? LayerShell.Window.KeyboardInteractivityOnDemand
                                                              : LayerShell.Window.KeyboardInteractivityNone
    LayerShell.Window.scope: "ai-sidebar"

    // Each tab carries its web app's base background colour (sampled from the live pages) so
    // the panel frame matches it: Gemini #1e1f20, ChatGPT #212121, Claude #262624.
    readonly property var tabs: [
        { "name": "Gemini",  "url": "https://gemini.google.com/app", "bg": "#1e1f20" },
        { "name": "ChatGPT", "url": "https://chatgpt.com/",          "bg": "#212121" },
        { "name": "Claude",  "url": "https://claude.ai/new",         "bg": "#262624" }
    ]
    property int current: 0
    readonly property color tabBg: tabs[current].bg

    // Fullscreen transparent catcher (one layer below the sidebar) — a real click anywhere
    // outside the panel dismisses it. It's cheap (no web content) so we map/unmap it normally.
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

    Rectangle {                          // panel; colour tracks the active tab so the rounded
        id: panel                        // top corners + bottom inset blend into the web page.
        anchors.fill: parent
        radius: 16
        color: win.tabBg

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 0           // web goes edge-to-edge
            spacing: 0

            RowLayout {                  // pill switcher (only this has padding)
                Layout.fillWidth: true
                Layout.topMargin: 10
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                Layout.bottomMargin: 8
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

            Rectangle {                  // web area: edge-to-edge sides/top; bottom inset by the
                Layout.fillWidth: true   // corner radius so the panel's rounded bottom corners
                Layout.fillHeight: true  // show — in the tab's own colour, so the inset is invisible.
                Layout.bottomMargin: 16
                color: win.tabBg
                clip: true
                StackLayout {
                    anchors.fill: parent
                    currentIndex: win.current
                    Repeater {
                        model: win.tabs
                        delegate: Item {
                            required property var modelData
                            required property int index
                            WebEngineView {
                                id: view
                                anchors.fill: parent
                                profile: aiProfile
                                url: parent.modelData.url
                                backgroundColor: parent.modelData.bg   // opaque: no blank/flash
                                onLoadingChanged: (req) => {
                                    if (req.status === WebEngineView.LoadStartedStatus) cover.opacity = 1;
                                    else if (req.status === WebEngineView.LoadSucceededStatus
                                          || req.status === WebEngineView.LoadFailedStatus) cover.opacity = 0;
                                }
                                // A render-process crash (GPU context loss, OOM) otherwise leaves
                                // the view permanently BLACK. Reload so it self-recovers.
                                onRenderProcessTerminated: (status, code) => {
                                    if (status !== WebEngineView.NormalTerminationStatus) {
                                        cover.opacity = 1;
                                        crashReload.start();
                                    }
                                }
                                Timer { id: crashReload; interval: 400; onTriggered: view.reload() }
                            }
                            Rectangle {
                                id: cover
                                anchors.fill: parent
                                color: parent.modelData.bg
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
