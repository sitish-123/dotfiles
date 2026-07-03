import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Overview (hyprtasking) configuration. Reads the LIVE plugin values via
// `hyprctl getoption`, applies changes instantly via `hyprctl eval hl.config(...)`,
// and persists them to ~/.config/hypr/custom/hyprtasking.lua (the data file consumed
// by hyprland/hyprtasking.lua) so they survive a reload/reboot. See the fork:
// ~/Projects/hyprtasking.
ContentPage {
    id: root
    forceWidth: true

    // --- model (initialised from the live plugin, then user-editable) ----------
    property bool loaded: false
    property bool enabledOverview: true
    property bool adaptive: true
    property int rows: 3
    property int cols: 4
    property int gapSize: 10
    property int rounding: 14
    property bool blurBg: true
    property bool gesturesEnabled: true
    property int openFingers: 4
    property int openDistance: 120
    property int moveFingers: 3

    readonly property string home: Quickshell.env("HOME")
    readonly property string luaPath: home + "/.config/hypr/custom/hyprtasking.lua"

    // --- read current values from the running plugin ---------------------------
    Process {
        id: reader
        running: true
        command: ["bash", "-c",
            'g(){ hyprctl getoption "plugin:hyprtasking:$1" 2>/dev/null | grep -oE "(int|float): [-0-9.]+" | awk \'{print $2}\'; }; ' +
            'echo "blur_bg=$(g blur_bg)"; echo "rounding=$(g rounding)"; echo "gap_size=$(g gap_size)"; ' +
            'echo "adaptive=$(g grid:adaptive)"; echo "rows=$(g grid:rows)"; echo "cols=$(g grid:cols)"; ' +
            'echo "gestures_enabled=$(g gestures:enabled)"; ' +
            'echo "open_fingers=$(g gestures:open_fingers)"; echo "open_distance=$(g gestures:open_distance)"; ' +
            'echo "move_fingers=$(g gestures:move_fingers)"; ' +
            'echo "state=$(cat "$HOME/.config/hypr/custom/overview.state" 2>/dev/null)"']
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                for (const line of text.trim().split("\n")) {
                    const i = line.indexOf("="); if (i < 0) continue;
                    map[line.slice(0, i)] = line.slice(i + 1).trim();
                }
                const num = (k, d) => { const v = parseFloat(map[k]); return isNaN(v) ? d : v; };
                root.blurBg = num("blur_bg", 1) !== 0;
                root.rounding = num("rounding", 14);
                root.gapSize = num("gap_size", 10);
                root.adaptive = num("adaptive", 1) !== 0;
                root.rows = num("rows", 3);
                root.cols = num("cols", 4);
                root.openFingers = num("open_fingers", 4);
                root.openDistance = num("open_distance", 120);
                root.moveFingers = num("move_fingers", 3);
                root.gesturesEnabled = num("gestures_enabled", 1) !== 0;
                root.enabledOverview = (map["state"] ?? "hyprtasking") !== "none";
                root.loaded = true;   // gate change handlers so the reads above don't self-apply
            }
        }
    }

    // --- persistence: write the data file the lua logic consumes ---------------
    FileView { id: luaFile; path: "file://" + root.luaPath }

    function persist() {
        const b = v => v ? "true" : "false";
        luaFile.setText(
`-- Hyprtasking overview settings — managed by Settings > Overview (edit freely too).
-- Consumed by hyprland/hyprtasking.lua. Set enabled=false to disable the overview.
return {
    enabled = ${b(root.enabledOverview)},
    settings = {
        layout               = "grid",
        gap_size             = ${root.gapSize},
        rounding             = ${root.rounding},
        blur_bg              = ${b(root.blurBg)},
        bg_color             = 0x00000066,
        exit_on_hovered      = true,
        plus_on_empty        = true,
        focus_follows_cursor = true,
        grid = { adaptive = ${b(root.adaptive)}, rows = ${root.rows}, cols = ${root.cols}, loop = true },
    },
    gestures = {
        enabled = ${b(root.gesturesEnabled)},
        open_fingers  = ${root.openFingers},
        open_distance = ${root.openDistance},
        open_positive = true,
        move_fingers  = ${root.moveFingers},
        move_distance = 300,
    },
    keybinds = {
        load = "SUPER + CTRL + 1", off = "SUPER + CTRL + 0",
        toggle = "SUPER + grave", toggle2 = "SUPER + Space",
    },
}
`);
    }

    // --- apply live (instant, no reload) ---------------------------------------
    function applyLive() {
        if (!root.enabledOverview) return;
        const cfg = `hl.config({plugin={hyprtasking={`
            + `gap_size=${root.gapSize},rounding=${root.rounding},blur_bg=${root.blurBg ? 1 : 0},`
            + `grid={adaptive=${root.adaptive},rows=${root.rows},cols=${root.cols}},`
            + `gestures={enabled=${root.gesturesEnabled},open_fingers=${root.openFingers},open_distance=${root.openDistance},move_fingers=${root.moveFingers}}`
            + `}}})`;
        Quickshell.execDetached(["hyprctl", "eval", cfg]);
    }

    // Called by every control on change: apply immediately + save to the data file.
    function change() {
        if (!root.loaded) return;
        root.applyLive();
        root.persist();
    }

    function setEnabled(on) {
        root.enabledOverview = on;
        Quickshell.execDetached(["bash", "-c",
            `~/.config/hypr/custom/scripts/overview-switch.sh ${on ? "hyprtasking" : "off"}`]);
        root.persist();
    }

    // ── Enable ────────────────────────────────────────────────────────────────
    ContentSection {
        icon: "grid_view"
        title: Translation.tr("Overview")

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            text: Translation.tr("Workspace overview (hyprtasking). 4-finger swipe up, SUPER+grave, or SUPER+Space to open. Changes apply live and are saved to custom/hyprtasking.lua.")
        }

        ConfigSwitch {
            buttonIcon: "toggle_on"
            text: Translation.tr("Enable overview plugin")
            checked: root.enabledOverview
            onCheckedChanged: if (root.loaded && checked !== root.enabledOverview) root.setEnabled(checked)
        }
    }

    // ── Grid ──────────────────────────────────────────────────────────────────
    ContentSection {
        icon: "grid_on"
        title: Translation.tr("Grid")
        enabled: root.enabledOverview

        ConfigSwitch {
            buttonIcon: "auto_awesome_mosaic"
            text: Translation.tr("Adaptive grid (size to workspace count)")
            checked: root.adaptive
            onCheckedChanged: { if (checked !== root.adaptive) { root.adaptive = checked; root.change(); } }
        }
        ConfigRow {
            ConfigSpinBox {
                icon: "table_rows"
                text: Translation.tr("Rows")
                value: root.rows; from: 1; to: 6; stepSize: 1
                enabled: !root.adaptive
                onValueChanged: { if (value !== root.rows) { root.rows = value; root.change(); } }
            }
            ConfigSpinBox {
                icon: "view_column"
                text: Translation.tr("Columns")
                value: root.cols; from: 1; to: 6; stepSize: 1
                enabled: !root.adaptive
                onValueChanged: { if (value !== root.cols) { root.cols = value; root.change(); } }
            }
        }
        ConfigSpinBox {
            icon: "space_bar"
            text: Translation.tr("Gap size (px)")
            value: root.gapSize; from: 0; to: 60; stepSize: 2
            onValueChanged: { if (value !== root.gapSize) { root.gapSize = value; root.change(); } }
        }
    }

    // ── Appearance ──────────────────────────────────────────────────────────────
    ContentSection {
        icon: "palette"
        title: Translation.tr("Appearance")
        enabled: root.enabledOverview

        ConfigSwitch {
            buttonIcon: "blur_on"
            text: Translation.tr("Blur background")
            checked: root.blurBg
            onCheckedChanged: { if (checked !== root.blurBg) { root.blurBg = checked; root.change(); } }
        }
        ConfigSpinBox {
            icon: "rounded_corner"
            text: Translation.tr("Tile rounding")
            value: root.rounding; from: 0; to: 40; stepSize: 2
            onValueChanged: { if (value !== root.rounding) { root.rounding = value; root.change(); } }
        }
    }

    // ── Gestures ────────────────────────────────────────────────────────────────
    ContentSection {
        icon: "swipe"
        title: Translation.tr("Gestures")
        enabled: root.enabledOverview

        ConfigSwitch {
            buttonIcon: "gesture"
            text: Translation.tr("Enable trackpad gestures")
            checked: root.gesturesEnabled
            onCheckedChanged: { if (checked !== root.gesturesEnabled) { root.gesturesEnabled = checked; root.change(); } }
        }
        ConfigRow {
            enabled: root.gesturesEnabled
            ConfigSpinBox {
                icon: "touch_app"
                text: Translation.tr("Open fingers")
                value: root.openFingers; from: 3; to: 4; stepSize: 1
                onValueChanged: { if (value !== root.openFingers) { root.openFingers = value; root.change(); } }
            }
            ConfigSpinBox {
                icon: "touch_app"
                text: Translation.tr("Move fingers")
                value: root.moveFingers; from: 3; to: 4; stepSize: 1
                onValueChanged: { if (value !== root.moveFingers) { root.moveFingers = value; root.change(); } }
            }
        }
        ConfigSpinBox {
            icon: "open_in_full"
            text: Translation.tr("Open swipe distance")
            value: root.openDistance; from: 40; to: 400; stepSize: 20
            enabled: root.gesturesEnabled
            onValueChanged: { if (value !== root.openDistance) { root.openDistance = value; root.change(); } }
        }
    }
}
