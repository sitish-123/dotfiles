import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Autostart editor. Manages user startup commands as a data table in
// ~/.config/hypr/custom/autostart.lua, consumed by hyprland/autostart.lua (each
// enabled command runs once on Hyprland start). Separate from custom/execs.lua
// (critical session bringup) so the GUI never clobbers that. Takes effect next login.
ContentPage {
    id: root
    forceWidth: true

    readonly property string luaPath: Quickshell.env("HOME") + "/.config/hypr/custom/autostart.lua"
    property bool loaded: false

    ListModel { id: cmdModel }

    FileView {
        id: luaFile
        path: "file://" + root.luaPath
        onLoaded: root.parseInto()
        onLoadFailed: (error) => { root.loaded = true; }
    }

    function unesc(s) { return String(s).replace(/\\"/g, '"').replace(/\\\\/g, '\\'); }
    function esc(s) { return String(s).replace(/\\/g, '\\\\').replace(/"/g, '\\"'); }

    function parseInto() {
        cmdModel.clear();
        const text = luaFile.text();
        const re = /\{\s*cmd\s*=\s*"((?:[^"\\]|\\.)*)"\s*,\s*enabled\s*=\s*(true|false)\s*\}/g;
        let m;
        while ((m = re.exec(text)) !== null)
            cmdModel.append({ cmd: root.unesc(m[1]), enabled: m[2] === "true" });
        root.loaded = true;
    }

    Timer { id: saveDebounce; interval: 300; onTriggered: root.save() }
    function scheduleSave() { if (root.loaded) saveDebounce.restart(); }

    function save() {
        let body = "";
        for (let i = 0; i < cmdModel.count; i++) {
            const c = cmdModel.get(i);
            if (!c.cmd || c.cmd.length === 0) continue;
            body += '        { cmd = "' + root.esc(c.cmd) + '", enabled = ' + (c.enabled ? "true" : "false") + ' },\n';
        }
        luaFile.setText(
            "-- User autostart commands — managed by Settings > Autostart (edit freely too).\n" +
            "-- Consumed by hyprland/autostart.lua; each enabled command runs once on start.\n" +
            "return {\n    commands = {\n" + body + "    },\n}\n");
    }

    ContentSection {
        icon: "rocket_launch"
        title: Translation.tr("Autostart")

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            text: Translation.tr("Commands run once when Hyprland starts, in addition to the shipped session startup. Toggle off to disable without deleting. Takes effect on next login. Saved to custom/autostart.lua.")
        }

        Repeater {
            model: cmdModel
            delegate: RowLayout {
                required property int index
                required property string cmd
                required property bool enabled
                Layout.fillWidth: true
                spacing: 6

                RippleButton {
                    implicitWidth: 36; implicitHeight: 36
                    buttonRadius: Appearance.rounding.full
                    onClicked: { cmdModel.setProperty(index, "enabled", !enabled); root.scheduleSave(); }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: enabled ? "toggle_on" : "toggle_off"
                        iconSize: 24
                        color: enabled ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                    }
                    StyledToolTip { text: enabled ? Translation.tr("Enabled — click to disable") : Translation.tr("Disabled — click to enable") }
                }
                MaterialTextField {
                    Layout.fillWidth: true
                    text: cmd
                    placeholderText: Translation.tr("command to run")
                    enabled: parent.enabled
                    onEditingFinished: { cmdModel.setProperty(index, "cmd", text); root.scheduleSave(); }
                }
                RippleButton {
                    implicitWidth: 36; implicitHeight: 36
                    buttonRadius: Appearance.rounding.full
                    onClicked: { cmdModel.remove(index); root.scheduleSave(); }
                    contentItem: MaterialSymbol { anchors.centerIn: parent; text: "delete"; iconSize: 20 }
                    StyledToolTip { text: Translation.tr("Remove") }
                }
            }
        }

        RippleButtonWithIcon {
            materialIcon: "add"
            mainText: Translation.tr("Add command")
            onClicked: cmdModel.append({ cmd: "", enabled: true })
        }
    }
}
