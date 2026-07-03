import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// Keybinds editor. Reads the GUI data table in ~/.config/hypr/custom/keybinds.lua
// (consumed by hyprland/userbinds.lua), presents every bind as an editable row grouped
// into collapsible sections, and writes it back. Features: action-type dropdown, an
// app/service picker for "Run command" binds, and live conflict detection (same combo
// bound twice). Changes save to the file (debounced); "Apply" does a ws-preserving reload.
ContentPage {
    id: root
    forceWidth: true

    readonly property string luaPath: Quickshell.env("HOME") + "/.config/hypr/custom/keybinds.lua"
    property bool loaded: false
    // action metadata: value -> {label, needsArg, hint, appPicker}
    readonly property var actionMeta: ({
        "exec":            { label: "Run command",              arg: true,  hint: "shell command", app: true },
        "global":          { label: "Shell action (IPC)",       arg: true,  hint: "quickshell:…" },
        "focus_ws":        { label: "Focus workspace",          arg: true,  hint: "1, r+1, special" },
        "focus_ws_group":  { label: "Focus workspace (in group)", arg: true, hint: "1–10" },
        "focus_dir":       { label: "Focus window (direction)", arg: true,  hint: "l / r / u / d" },
        "move_ws":         { label: "Move window → workspace",  arg: true,  hint: "1, r+1, special" },
        "move_ws_nf":      { label: "Move → workspace (stay)",  arg: true,  hint: "1, special:…" },
        "move_ws_group":   { label: "Move → workspace (in group)", arg: true, hint: "1–10" },
        "move_dir":        { label: "Move window (direction)",  arg: true,  hint: "l / r / u / d" },
        "drag":            { label: "Move window (mouse)",      arg: false },
        "resize":          { label: "Resize window (mouse)",    arg: false },
        "resize_exact":    { label: "Resize window (exact)",    arg: true,  hint: "W H, e.g. 640 480" },
        "close":           { label: "Close window",             arg: false },
        "float":           { label: "Toggle floating",          arg: false },
        "fullscreen":      { label: "Fullscreen / maximize",    arg: true,  hint: "fullscreen / maximized" },
        "fs_state":        { label: "Fullscreen (spoof)",       arg: false },
        "pin":             { label: "Pin window",               arg: false },
        "layout":          { label: "Layout message",           arg: true,  hint: "splitratio +0.1" },
        "special":         { label: "Toggle special workspace", arg: true,  hint: "special" },
        "zoom":            { label: "Zoom screen",              arg: true,  hint: "+0.3 / -0.3" }
    })
    readonly property var actionOptions: {
        const keys = Object.keys(root.actionMeta);
        return keys.map(k => ({ value: k, displayName: root.actionMeta[k].label, icon: "" }));
    }
    readonly property var sectionOrder: ["Apps", "Shell", "Media", "Utilities", "Window", "Workspaces", "Screen", "Session", "Custom"]
    property var collapsed: ({})

    ListModel { id: binds }

    // ── load / parse ──────────────────────────────────────────────────────────
    FileView {
        id: luaFile
        path: "file://" + root.luaPath
        onLoaded: root.parseInto()
        onLoadFailed: (error) => { root.loaded = true; }
    }

    function unesc(s) { return String(s).replace(/\\n/g, "\n").replace(/\\t/g, "\t").replace(/\\r/g, "\r").replace(/\\"/g, '"').replace(/\\\\/g, "\\"); }
    function esc(s) { return String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n").replace(/\t/g, "\\t").replace(/\r/g, "\\r"); }
    function field(line, name) { const m = line.match(new RegExp(name + ' = "((?:[^"\\\\]|\\\\.)*)"')); return m ? root.unesc(m[1]) : ""; }

    function parseInto() {
        const rows = [];
        for (const line of luaFile.text().split("\n")) {
            if (!/action = "/.test(line)) continue;
            const fl = line.match(/flags = \{([^}]*)\}/);
            const flags = {};
            if (fl) { const fre = /(\w+) = true/g; let fm; while ((fm = fre.exec(fl[1])) !== null) flags[fm[1]] = true; }
            rows.push({
                mods: root.field(line, "mods"), key: root.field(line, "key"),
                action: root.field(line, "action"), arg: root.field(line, "arg"),
                desc: root.field(line, "desc"), section: root.field(line, "section") || "Custom",
                locked: !!flags.locked, repeating: !!flags.repeating, ignore_mods: !!flags.ignore_mods,
                transparent: !!flags.transparent, release: !!flags.release, mouse: !!flags.mouse,
                non_consuming: !!flags.non_consuming
            });
        }
        rows.sort((a, b) => {
            const ia = root.sectionOrder.indexOf(a.section), ib = root.sectionOrder.indexOf(b.section);
            return (ia < 0 ? 99 : ia) - (ib < 0 ? 99 : ib);
        });
        binds.clear();
        for (const r of rows) binds.append(r);
        root.loaded = true;
        root.recomputeConflicts();
    }

    // ── conflicts ─────────────────────────────────────────────────────────────
    property var conflictKeys: ({})
    function comboOf(i) { const b = binds.get(i); return (b.mods || "") + "|" + (b.key || ""); }
    function recomputeConflicts() {
        // Group binds by combo. The common ii idiom binds the SAME combo to a quickshell
        // `global` action + an `exec` fallback (guarded by `qsIsAlive ||`) — that's
        // intentional, not a conflict. Flag a combo only when it's duplicated AND isn't
        // that idiom: i.e. more than one non-fallback action lands on it.
        const groups = {};
        for (let i = 0; i < binds.count; i++) {
            const b = binds.get(i);
            const c = (b.mods || "") + "|" + (b.key || "");
            (groups[c] = groups[c] || []).push(b.action);
        }
        const ck = {};
        for (const c in groups) {
            const acts = groups[c];
            if (acts.length < 2) continue;
            const globals = acts.filter(a => a === "global").length;
            const others = acts.length - globals - acts.filter(a => a === "exec").length;
            const benignFallback = (others === 0 && globals === 1); // 1 global + only exec(s)
            if (!benignFallback) ck[c] = acts.length;
        }
        root.conflictKeys = ck;
    }
    readonly property int conflictCount: Object.keys(conflictKeys).length

    // ── persist ───────────────────────────────────────────────────────────────
    Timer { id: saveDebounce; interval: 350; onTriggered: root.save() }
    function scheduleSave() { if (root.loaded) { root.recomputeConflicts(); saveDebounce.restart(); } }

    function save() {
        const FLAGS = ["locked", "repeating", "ignore_mods", "transparent", "release", "mouse", "non_consuming"];
        let body = "";
        for (let i = 0; i < binds.count; i++) {
            const b = binds.get(i);
            if (!b.key || b.key.length === 0) continue;
            const fs = FLAGS.filter(f => b[f]).map(f => f + " = true");
            const flagStr = fs.length ? ", flags = { " + fs.join(", ") + " }" : "";
            body += '        { mods = "' + root.esc(b.mods) + '", key = "' + root.esc(b.key) +
                '", action = "' + root.esc(b.action) + '", arg = "' + root.esc(b.arg) +
                '", desc = "' + root.esc(b.desc) + '", section = "' + root.esc(b.section) + '"' + flagStr + ' },\n';
        }
        luaFile.setText(
            "-- User keybinds — managed by Settings > Keybinds (edit freely too).\n" +
            "-- Consumed by hyprland/userbinds.lua. Each entry is one keybind.\n" +
            "return {\n    binds = {\n" + body + "    },\n}\n");
    }

    function applyReload() {
        Quickshell.execDetached(["bash", "-lc", "~/.config/hypr/custom/scripts/hypr-reload.sh 2>/dev/null || hyprctl reload"]);
    }

    // ── top bar ───────────────────────────────────────────────────────────────
    ContentSection {
        icon: "keyboard"
        title: Translation.tr("Keybinds")

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            text: Translation.tr("Every shortcut is editable here. Changes save to custom/keybinds.lua; click Apply to reload Hyprland. Dynamic binds (group-aware workspace switching, zoom) keep working.")
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            RippleButtonWithIcon {
                materialIcon: "add"
                mainText: Translation.tr("Add keybind")
                onClicked: {
                    binds.insert(0, { mods: "SUPER", key: "", action: "exec", arg: "", desc: "", section: "Custom",
                        locked: false, repeating: false, ignore_mods: false, transparent: false, release: false, mouse: false, non_consuming: false });
                    root.scheduleSave();
                }
            }
            Item { Layout.fillWidth: true }
            StyledText {
                visible: root.conflictCount > 0
                color: Appearance.m3colors.m3error
                font.pixelSize: Appearance.font.pixelSize.smaller
                text: "⚠ " + root.conflictCount + " " + Translation.tr("conflicting combo(s)")
            }
            RippleButtonWithIcon {
                materialIcon: "refresh"
                mainText: Translation.tr("Apply (reload)")
                onClicked: { saveDebounce.stop(); root.save(); root.applyReload(); }
            }
        }
    }

    // ── the list (flat, with inline section headers + collapse) ─────────────────
    ContentSection {
        Layout.fillWidth: true

        Repeater {
            model: binds
            delegate: ColumnLayout {
                id: rowWrap
                required property int index
                required property string mods
                required property string key
                required property string action
                required property string arg
                required property string desc
                required property string section
                required property bool locked
                required property bool repeating
                Layout.fillWidth: true
                spacing: 0

                readonly property bool sectionStart: index === 0 || binds.get(index - 1).section !== section
                readonly property bool sectionCollapsed: root.collapsed[section] === true
                readonly property bool conflict: root.conflictKeys[(mods || "") + "|" + (key || "")] !== undefined
                readonly property var meta: root.actionMeta[action] || { arg: false }

                // section header
                Rectangle {
                    visible: rowWrap.sectionStart
                    Layout.fillWidth: true
                    Layout.preferredHeight: visible ? 34 : 0
                    color: "transparent"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 2
                        MaterialSymbol {
                            text: rowWrap.sectionCollapsed ? "chevron_right" : "expand_more"
                            iconSize: 22; color: Appearance.colors.colOnLayer1
                        }
                        StyledText {
                            text: rowWrap.section
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnLayer1
                        }
                        Item { Layout.fillWidth: true }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            const c = Object.assign({}, root.collapsed);
                            c[rowWrap.section] = !(c[rowWrap.section] === true);
                            root.collapsed = c;
                        }
                    }
                }

                // bind row
                Rectangle {
                    Layout.fillWidth: true
                    visible: !rowWrap.sectionCollapsed
                    Layout.preferredHeight: visible ? rowLayout.implicitHeight + 10 : 0
                    radius: Appearance.rounding.small
                    color: rowWrap.conflict ? ColorUtils.transparentize(Appearance.m3colors.m3error, 0.85) : "transparent"

                    RowLayout {
                        id: rowLayout
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 8
                        anchors.rightMargin: 4
                        spacing: 5

                        MaterialSymbol {
                            visible: rowWrap.conflict
                            text: "warning"; iconSize: 18; color: Appearance.m3colors.m3error
                            StyledToolTip { text: Translation.tr("This key combo is bound more than once") }
                        }
                        MaterialTextField {
                            Layout.preferredWidth: 118
                            text: rowWrap.mods
                            placeholderText: "SUPER + ALT"
                            wrapMode: Text.NoWrap
                            onEditingFinished: { binds.setProperty(rowWrap.index, "mods", text); root.scheduleSave(); }
                        }
                        StyledText { text: "+"; color: Appearance.colors.colSubtext }
                        MaterialTextField {
                            Layout.preferredWidth: 78
                            text: rowWrap.key
                            placeholderText: "Q"
                            wrapMode: Text.NoWrap
                            onEditingFinished: { binds.setProperty(rowWrap.index, "key", text); root.scheduleSave(); }
                        }
                        StyledComboBox {
                            Layout.preferredWidth: 150
                            model: root.actionOptions
                            textRole: "displayName"
                            currentIndex: Math.max(0, root.actionOptions.findIndex(o => o.value === rowWrap.action))
                            onActivated: (i) => { binds.setProperty(rowWrap.index, "action", root.actionOptions[i].value); root.scheduleSave(); }
                        }
                        MaterialTextField {
                            Layout.fillWidth: true
                            visible: rowWrap.meta.arg === true
                            text: rowWrap.arg
                            placeholderText: rowWrap.meta.hint || Translation.tr("argument")
                            wrapMode: Text.NoWrap
                            onEditingFinished: { binds.setProperty(rowWrap.index, "arg", text); root.scheduleSave(); }
                        }
                        // app picker (only for Run command)
                        RippleButton {
                            visible: rowWrap.meta.app === true
                            implicitWidth: 34; implicitHeight: 34
                            buttonRadius: Appearance.rounding.full
                            onClicked: { appPicker.targetIndex = rowWrap.index; appPicker.open(); }
                            contentItem: MaterialSymbol { anchors.centerIn: parent; text: "apps"; iconSize: 20 }
                            StyledToolTip { text: Translation.tr("Pick an app") }
                        }
                        MaterialTextField {
                            Layout.preferredWidth: 150
                            text: rowWrap.desc
                            placeholderText: Translation.tr("description")
                            wrapMode: Text.NoWrap
                            onEditingFinished: { binds.setProperty(rowWrap.index, "desc", text); root.scheduleSave(); }
                        }
                        RippleButton {
                            implicitWidth: 34; implicitHeight: 34
                            buttonRadius: Appearance.rounding.full
                            onClicked: flagsPopup.openFor(rowWrap.index)
                            contentItem: MaterialSymbol { anchors.centerIn: parent; text: "tune"; iconSize: 18
                                color: (rowWrap.locked || rowWrap.repeating) ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1 }
                            StyledToolTip { text: Translation.tr("Flags (locked, repeating, …)") }
                        }
                        RippleButton {
                            implicitWidth: 34; implicitHeight: 34
                            buttonRadius: Appearance.rounding.full
                            onClicked: { binds.remove(rowWrap.index); root.scheduleSave(); }
                            contentItem: MaterialSymbol { anchors.centerIn: parent; text: "delete"; iconSize: 18 }
                            StyledToolTip { text: Translation.tr("Remove") }
                        }
                    }
                }
            }
        }
    }

    // ── flags popup ─────────────────────────────────────────────────────────────
    Popup {
        id: flagsPopup
        property int idx: -1
        function openFor(i) { idx = i; open(); }
        modal: true; dim: true
        anchors.centerIn: Overlay.overlay
        padding: 16
        background: Rectangle { color: Appearance.m3colors.m3surfaceContainerHigh; radius: Appearance.rounding.normal }
        contentItem: ColumnLayout {
            spacing: 4
            StyledText { text: Translation.tr("Bind flags"); font.weight: Font.Medium; font.pixelSize: Appearance.font.pixelSize.normal }
            Repeater {
                model: ["locked", "repeating", "ignore_mods", "transparent", "release", "mouse", "non_consuming"]
                delegate: ConfigSwitch {
                    required property string modelData
                    text: modelData
                    checked: flagsPopup.idx >= 0 ? (binds.get(flagsPopup.idx)[modelData] === true) : false
                    onCheckedChanged: { if (flagsPopup.idx >= 0 && checked !== (binds.get(flagsPopup.idx)[modelData] === true)) { binds.setProperty(flagsPopup.idx, modelData, checked); root.scheduleSave(); } }
                }
            }
        }
    }

    // ── app picker ──────────────────────────────────────────────────────────────
    Popup {
        id: appPicker
        property int targetIndex: -1
        modal: true; dim: true
        anchors.centerIn: Overlay.overlay
        width: 420; height: 460; padding: 12
        onOpened: { appSearchField.text = ""; appSearchField.forceActiveFocus(); }
        background: Rectangle { color: Appearance.m3colors.m3surfaceContainerHigh; radius: Appearance.rounding.normal }
        contentItem: ColumnLayout {
            spacing: 8
            MaterialTextField {
                id: appSearchField
                Layout.fillWidth: true
                placeholderText: Translation.tr("Search apps…")
            }
            StyledListView {
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true
                model: {
                    const q = appSearchField.text.trim();
                    const list = q.length > 0 ? AppSearch.fuzzyQuery(q) : AppSearch.list;
                    return list.slice(0, 40);
                }
                delegate: RippleButton {
                    required property var modelData
                    width: ListView.view ? ListView.view.width : 0
                    implicitHeight: 40
                    onClicked: {
                        const cmd = ((modelData.execString || modelData.command || modelData.id || "") + "").replace(/ ?%[a-zA-Z]/g, "").trim();
                        if (appPicker.targetIndex >= 0) {
                            binds.setProperty(appPicker.targetIndex, "action", "exec");
                            binds.setProperty(appPicker.targetIndex, "arg", cmd);
                            if (!binds.get(appPicker.targetIndex).desc) binds.setProperty(appPicker.targetIndex, "desc", "App: " + (modelData.name || cmd));
                            root.scheduleSave();
                        }
                        appPicker.close();
                    }
                    contentItem: RowLayout {
                        spacing: 8
                        IconImage { implicitSize: 26; source: Quickshell.iconPath(modelData.icon, "application-x-executable") }
                        StyledText { Layout.fillWidth: true; text: modelData.name || ""; elide: Text.ElideRight }
                    }
                }
            }
        }
    }
}
