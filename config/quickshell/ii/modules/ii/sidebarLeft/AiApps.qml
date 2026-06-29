import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

// Launcher tab for the AI assistants. These are the self-built apps (see
// bootstrap/webapps/): Gemini + ChatGPT as chromium PWAs, Claude Code in a terminal.
// No API keys, no embedded webview — just launches the real apps and closes the sidebar.
Item {
    id: root

    function launch(cmd) {
        Quickshell.execDetached(["bash", "-lc", cmd]);
        GlobalStates.sidebarLeftOpen = false;
    }

    readonly property string iconDir: (Quickshell.env("HOME") ?? "") + "/.local/share/icons/ii-webapps/"
    readonly property var apps: [
        { "name": "Gemini",      "icon": "gemini.svg",  "desc": "Google Gemini (web app)",
          "cmd": "chromium --app=https://gemini.google.com/app --class=Gemini --name=Gemini" },
        { "name": "ChatGPT",     "icon": "chatgpt.svg", "desc": "OpenAI ChatGPT (web app)",
          "cmd": "chromium --app=https://chatgpt.com/ --class=ChatGPT --name=ChatGPT" },
        { "name": "Claude Code", "icon": "claude.svg",  "desc": "Anthropic CLI in a terminal",
          "cmd": "kitty -1 bash -lc 'command -v claude >/dev/null && exec claude || { echo \"Install: npm i -g @anthropic-ai/claude-code\"; exec bash; }'" },
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Assistants")
            font.pixelSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colOnLayer1
        }
        StyledText {
            Layout.fillWidth: true
            Layout.bottomMargin: 4
            text: Translation.tr("Opens the app in its own window")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            wrapMode: Text.Wrap
        }

        Repeater {
            model: root.apps
            delegate: RippleButton {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 60
                buttonRadius: Appearance.rounding.normal
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                onClicked: root.launch(modelData.cmd)
                contentItem: RowLayout {
                    spacing: 14
                    Image {
                        Layout.leftMargin: 6
                        source: "file://" + root.iconDir + modelData.icon
                        sourceSize.width: 36; sourceSize.height: 36
                        Layout.preferredWidth: 36; Layout.preferredHeight: 36
                        fillMode: Image.PreserveAspectFit
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        StyledText {
                            text: modelData.name
                            font.pixelSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnLayer1
                        }
                        StyledText {
                            text: modelData.desc
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                    }
                    MaterialSymbol {
                        Layout.rightMargin: 10
                        text: "open_in_new"
                        iconSize: 20
                        color: Appearance.colors.colSubtext
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
