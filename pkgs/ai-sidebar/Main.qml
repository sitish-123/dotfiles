import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.layershell 1.0 as LayerShell
import QtWebEngine

// Floating layer-shell sidebar embedding the logged-in Gemini / ChatGPT / Claude web apps.
//
// VISIBILITY. The Wayland surface stays mapped the whole time; we hide by fading the panel's
// content to opacity 0 (and parking it slightly off to the left). Two reasons it must work
// this way on this stack:
//   * Unmapping the window (visible:false) makes QtWebEngine come back BLACK on reopen — it
//     never submits a frame to the freshly-created surface until you click it.
//   * Sliding off-screen via a negative LayerShell margin does NOT work either: layer-shell-qt
//     doesn't re-commit margins after the surface is configured, so the panel never moved and
//     toggling looked like a no-op ("doesn't open when triggered again").
// Keeping it mapped + opacity-hidden avoids both. When the content is fully transparent the
// Hyprland `ignore_alpha = 0.3` layer rule makes those pixels click-through, so a "hidden"
// panel doesn't block the left strip of the screen.
//
// WEB VIEWS. Loaded LAZILY (a tab spawns its Chromium renderer only when first opened) and the
// non-current tabs are Frozen (and Discarded after a long idle). The previous version left all
// three renderers Active forever, so one would leak into multiple GB / peg a core and drag the
// whole panel down. At most one renderer (the current tab) is ever Active now.
Window {
    id: win
    visible: true                        // ALWAYS mapped — see VISIBILITY note above
    width: 460                           // match the right sidebar (Appearance.sizes.sidebarWidth)
    color: "transparent"

    readonly property int gap: 8         // float gap on the anchored edges (top/left/bottom)

    // `live` = web content is actually being rendered. It's kept on during the open/close slide
    // (so you see the animation) and switched OFF a moment after the panel finishes sliding
    // closed. Marking the views not-visible (item-level — the surface is NOT destroyed, so no
    // black on reopen) lets QtWebEngine FREEZE the renderers, dropping their CPU to ~0 while
    // hidden. `deepSuspend` then discards them after a longer idle to also free their memory.
    property bool live: true
    property bool deepSuspend: false

    LayerShell.Window.anchors: LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.exclusionZone: 0
    // Static float gap (applied once at surface configure — must NOT depend on Controller.shown:
    // layer-shell-qt won't re-commit margin changes at runtime).
    LayerShell.Window.margins: ({ "left": gap, "top": gap, "right": 0, "bottom": gap })
    LayerShell.Window.keyboardInteractivity: Controller.shown ? LayerShell.Window.KeyboardInteractivityOnDemand
                                                              : LayerShell.Window.KeyboardInteractivityNone
    LayerShell.Window.scope: "ai-sidebar"

    Connections {
        target: Controller
        function onShownChanged() {
            if (Controller.shown) {
                win.live = true;                 // render immediately so the slide-in shows content
                win.deepSuspend = false;
                collapseTimer.stop();
                discardTimer.stop();
            } else {
                collapseTimer.restart();         // freeze renderers once the slide-out has played
                discardTimer.restart();           // and reclaim their memory after a long idle
            }
        }
    }
    Timer { id: collapseTimer; interval: 260;          onTriggered: win.live = false }       // ~ slide duration
    Timer { id: discardTimer;  interval: 10 * 60 * 1000; onTriggered: win.deepSuspend = true }

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

        // Hide = slide the whole panel off the left edge (open <-> closed), like the right
        // sidebar, plus a fade. The motion is INSIDE the fixed, always-mapped surface (never a
        // surface resize/unmap), so it stays smooth and QtWebEngine keeps its painted frame —
        // no black on reopen. At rest-closed the panel is fully transparent + slid away, which
        // the Hyprland `ignore_alpha = 0.3` layer rule turns into click-through.
        // NOTE: must use a Translate transform, NOT `x:` — `anchors.fill` pins x, so assigning
        // `x` is silently ignored (that left the panel stuck open).
        opacity: Controller.shown ? 1 : 0
        transform: Translate {
            x: Controller.shown ? 0 : -(win.width + 24)
            Behavior on x { NumberAnimation { duration: 230; easing.type: Easing.OutCubic } }
        }
        Behavior on opacity { NumberAnimation { duration: 230; easing.type: Easing.OutCubic } }

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
                // Not-visible once collapsed -> QtWebEngine freezes the renderers (CPU ~0).
                // The window surface itself stays mapped, so this never causes a black reopen.
                visible: win.live
                StackLayout {
                    anchors.fill: parent
                    currentIndex: win.current
                    Repeater {
                        model: win.tabs
                        delegate: Item {
                            id: tab
                            required property var modelData
                            required property int index
                            // Lazy: only spawn this tab's renderer once it's first opened.
                            property bool loadedOnce: (index === win.current)
                            Connections {
                                target: win
                                function onCurrentChanged() { if (win.current === tab.index) tab.loadedOnce = true; }
                            }

                            Loader {
                                anchors.fill: parent
                                active: tab.loadedOnce
                                sourceComponent: WebEngineView {
                                    profile: aiProfile
                                    url: tab.modelData.url
                                    backgroundColor: tab.modelData.bg   // opaque: no blank/flash
                                    // At most one Active renderer (the current tab). Backgrounded
                                    // tabs are Frozen (paused, kept warm); after a long hide they're
                                    // Discarded to free memory. Frozen/Discarded only stick on a
                                    // non-visible view, which is exactly the non-current tabs here.
                                    // Open: current tab Active, the rest Frozen. Hidden (not live):
                                    // everything Frozen, then Discarded after a long idle. Frozen/
                                    // Discarded only "stick" on a non-visible view — which is exactly
                                    // the case for background tabs and for everything once collapsed.
                                    lifecycleState: !win.live
                                        ? (win.deepSuspend ? WebEngineView.LifecycleStateDiscarded
                                                           : WebEngineView.LifecycleStateFrozen)
                                        : (win.current === tab.index ? WebEngineView.LifecycleStateActive
                                                                     : WebEngineView.LifecycleStateFrozen)
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
                                    Timer { id: crashReload; interval: 400; onTriggered: parent.reload() }
                                }
                            }
                            Rectangle {
                                id: cover
                                anchors.fill: parent
                                color: tab.modelData.bg
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
