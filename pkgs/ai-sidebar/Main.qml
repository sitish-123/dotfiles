import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.layershell 1.0 as LayerShell
import QtWebEngine

// Floating layer-shell sidebar (like the old Quickshell one): inset + rounded, translucent
// so Hyprland's blur frosts it (see the layer rules in custom/rules.lua), slides in/out,
// and dismisses when you click outside. Embeds the logged-in Gemini/ChatGPT/Claude web
// apps with a pill switcher on top.
Window {
    id: win
    visible: Controller.shown
    width: 500
    color: "transparent"

    LayerShell.Window.anchors: LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom
    LayerShell.Window.layer: LayerShell.Window.LayerTop
    LayerShell.Window.exclusionZone: 0
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand
    LayerShell.Window.activateOnShow: true
    LayerShell.Window.scope: "ai-sidebar"

    // Tap-outside-to-dismiss: arm only once the panel has actually grabbed focus (so it
    // doesn't dismiss itself in the brief unfocused moment right after showing).
    property bool armed: false
    onActiveChanged: {
        if (active) armed = true;
        else if (armed) Controller.shown = false;
    }
    Connections {
        target: Controller
        function onShownChanged() { if (Controller.shown) win.armed = false; }
    }

    readonly property var tabs: [
        { "name": "Gemini",  "url": "https://gemini.google.com/app" },
        { "name": "ChatGPT", "url": "https://chatgpt.com/" },
        { "name": "Claude",  "url": "https://claude.ai/new" }
    ]
    property int current: 0

    WebEngineProfile {
        id: aiProfile
        storageName: "ai-sidebar"        // persists cookies/login under ~/.local/share
        offTheRecord: false
    }

    Rectangle {                          // floating, inset, rounded, translucent panel
        id: panel
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.topMargin: 10
        anchors.rightMargin: 10
        anchors.bottomMargin: 60         // clear the bottom ii bar
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
                color: "transparent"
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
                                backgroundColor: "transparent"
                                // No white flash: keep a dark cover up until the page has
                                // actually painted, fade it out, and bring it back on nav.
                                onLoadingChanged: (req) => {
                                    if (req.status === WebEngineView.LoadStartedStatus) cover.opacity = 1;
                                    else if (req.status === WebEngineView.LoadSucceededStatus
                                          || req.status === WebEngineView.LoadFailedStatus) cover.opacity = 0;
                                }
                            }
                            Rectangle {
                                id: cover
                                anchors.fill: parent
                                color: Qt.rgba(0.07, 0.07, 0.09, 1.0)
                                opacity: 1
                                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                                BusyIndicator {
                                    anchors.centerIn: parent
                                    running: cover.opacity > 0.5
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
