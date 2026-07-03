import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Environment variables editor. Manages extra session env vars as a data table in
// ~/.config/hypr/custom/env.lua, consumed by hyprland/userenv.lua and applied on top
// of the shipped hyprland/env.lua. The GUI is the sole writer of that file, so it
// round-trips its own fixed format ({ name = "..", value = ".." }). Changes take
// effect on next login (env vars are set at session start).
ContentPage {
    id: root
    forceWidth: true

    readonly property string luaPath: Quickshell.env("HOME") + "/.config/hypr/custom/env.lua"
    property bool loaded: false

    ListModel { id: envModel }

    // --- persistence ----------------------------------------------------------
    FileView {
        id: luaFile
        path: "file://" + root.luaPath
        onLoaded: root.parseInto()
        onLoadFailed: (error) => { root.loaded = true; } // missing/empty -> start blank
    }

    function unesc(s) { return String(s).replace(/\\"/g, '"').replace(/\\\\/g, '\\'); }
    function esc(s) { return String(s).replace(/\\/g, '\\\\').replace(/"/g, '\\"'); }

    function parseInto() {
        envModel.clear();
        const text = luaFile.text();
        const re = /\{\s*name\s*=\s*"((?:[^"\\]|\\.)*)"\s*,\s*value\s*=\s*"((?:[^"\\]|\\.)*)"\s*\}/g;
        let m;
        while ((m = re.exec(text)) !== null)
            envModel.append({ name: root.unesc(m[1]), value: root.unesc(m[2]) });
        root.loaded = true;
    }

    Timer { id: saveDebounce; interval: 300; onTriggered: root.save() }
    function scheduleSave() { if (root.loaded) saveDebounce.restart(); }

    function save() {
        let body = "";
        for (let i = 0; i < envModel.count; i++) {
            const e = envModel.get(i);
            if (!e.name || e.name.length === 0) continue;
            body += '        { name = "' + root.esc(e.name) + '", value = "' + root.esc(e.value) + '" },\n';
        }
        luaFile.setText(
            "-- User environment variables — managed by Settings > Environment (edit freely too).\n" +
            "-- Consumed by hyprland/userenv.lua and applied after the shipped hyprland/env.lua.\n" +
            "return {\n    vars = {\n" + body + "    },\n}\n");
    }

    // --- UI -------------------------------------------------------------------
    ContentSection {
        icon: "terminal"
        title: Translation.tr("Environment variables")

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            text: Translation.tr("Extra variables exported to your Hyprland session, applied on top of the shipped defaults. Takes effect on next login. Saved to custom/env.lua.")
        }

        Repeater {
            model: envModel
            delegate: RowLayout {
                required property int index
                required property string name
                required property string value
                Layout.fillWidth: true
                spacing: 6

                MaterialTextField {
                    Layout.preferredWidth: 170
                    text: name
                    placeholderText: "NAME"
                    onEditingFinished: { envModel.setProperty(index, "name", text); root.scheduleSave(); }
                }
                StyledText { text: "="; color: Appearance.colors.colSubtext }
                MaterialTextField {
                    Layout.fillWidth: true
                    text: value
                    placeholderText: Translation.tr("value")
                    onEditingFinished: { envModel.setProperty(index, "value", text); root.scheduleSave(); }
                }
                RippleButton {
                    implicitWidth: 36; implicitHeight: 36
                    buttonRadius: Appearance.rounding.full
                    onClicked: { envModel.remove(index); root.scheduleSave(); }
                    contentItem: MaterialSymbol { anchors.centerIn: parent; text: "delete"; iconSize: 20 }
                    StyledToolTip { text: Translation.tr("Remove") }
                }
            }
        }

        RippleButtonWithIcon {
            materialIcon: "add"
            mainText: Translation.tr("Add variable")
            onClicked: envModel.append({ name: "", value: "" })
        }
    }
}
