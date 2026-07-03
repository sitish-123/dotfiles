import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Window Manager (Hyprland) input + appearance settings. Same data/logic model as the
// Overview page: reads LIVE values via `hyprctl getoption`, applies instantly via
// `hyprctl eval hl.config(...)`, and persists to ~/.config/hypr/custom/wm.lua (consumed
// by hyprland/wm.lua via deep-merge, so it survives reload/reboot and updates).
ContentPage {
    id: root
    forceWidth: true

    property bool loaded: false
    // input
    property real sensitivity: 0
    property int followMouse: 1
    property int repeatDelay: 250
    property int repeatRate: 35
    property bool naturalScroll: true
    property bool disableWhileTyping: false
    property bool clickfinger: true
    property real scrollFactor: 0.7
    // appearance
    property int gapsIn: 2
    property int gapsOut: 4
    property int borderSize: 1
    property int rounding: 18
    property bool blurEnabled: true
    property int blurSize: 10
    property int blurPasses: 3
    property bool dimInactive: true
    property real dimStrength: 0.05
    property bool animationsEnabled: true

    readonly property string home: Quickshell.env("HOME")

    // --- read current live values ----------------------------------------------
    Process {
        id: reader
        running: true
        command: ["bash", "-c",
            'g(){ hyprctl getoption "$1" 2>/dev/null | grep -E "^[[:space:]]*(int|float|bool):" | head -1 | sed -E "s/^[[:space:]]*(int|float|bool): *([^ ]*).*/\\2/"; }; ' +
            'echo "sensitivity=$(g input:sensitivity)"; echo "follow_mouse=$(g input:follow_mouse)"; ' +
            'echo "repeat_delay=$(g input:repeat_delay)"; echo "repeat_rate=$(g input:repeat_rate)"; ' +
            'echo "natural_scroll=$(g input:touchpad:natural_scroll)"; ' +
            'echo "dwt=$(g input:touchpad:disable_while_typing)"; echo "clickfinger=$(g input:touchpad:clickfinger_behavior)"; ' +
            'echo "scroll_factor=$(g input:touchpad:scroll_factor)"; ' +
            'echo "gaps_in=$(g general:gaps_in)"; echo "gaps_out=$(g general:gaps_out)"; echo "border=$(g general:border_size)"; ' +
            'echo "rounding=$(g decoration:rounding)"; echo "blur=$(g decoration:blur:enabled)"; ' +
            'echo "blur_size=$(g decoration:blur:size)"; echo "blur_passes=$(g decoration:blur:passes)"; ' +
            'echo "dim=$(g decoration:dim_inactive)"; echo "dim_strength=$(g decoration:dim_strength)"; ' +
            'echo "anim=$(g animations:enabled)"']
        stdout: StdioCollector {
            onStreamFinished: {
                const m = {};
                for (const line of text.trim().split("\n")) { const i = line.indexOf("="); if (i >= 0) m[line.slice(0, i)] = line.slice(i + 1).trim(); }
                // Numeric parse (int/float). getoption prints numbers here.
                const n = (k, d) => { const v = parseFloat(m[k]); return isNaN(v) ? d : v; };
                // Boolean parse. getoption prints `bool: true/false` — the WORD, not a
                // number, so the old numeric extraction always failed and every toggle
                // silently reverted to its default (and then clobbered the saved value).
                const tf = (k, d) => { const v = m[k]; if (v === "true" || v === "1") return true; if (v === "false" || v === "0") return false; return d; };
                root.sensitivity = n("sensitivity", 0);
                root.followMouse = n("follow_mouse", 1);
                root.repeatDelay = n("repeat_delay", 250);
                root.repeatRate = n("repeat_rate", 35);
                root.naturalScroll = tf("natural_scroll", true);
                root.disableWhileTyping = tf("dwt", false);
                root.clickfinger = tf("clickfinger", true);
                root.scrollFactor = n("scroll_factor", 0.7);
                root.gapsIn = n("gaps_in", 2);
                root.gapsOut = n("gaps_out", 4);
                root.borderSize = n("border", 1);
                root.rounding = n("rounding", 18);
                root.blurEnabled = tf("blur", true);
                root.blurSize = n("blur_size", 10);
                root.blurPasses = n("blur_passes", 3);
                root.dimInactive = tf("dim", true);
                root.dimStrength = n("dim_strength", 0.05);
                root.animationsEnabled = tf("anim", true);
                root.loaded = true;
            }
        }
    }

    // --- persist to the data file ----------------------------------------------
    FileView { id: wmFile; path: "file://" + root.home + "/.config/hypr/custom/wm.lua" }

    function persist() {
        const b = v => v ? "true" : "false";
        const f = v => v.toFixed(2);
        wmFile.setText(
`-- Window Manager settings — managed by Settings > Window Manager (edit freely too).
-- Consumed by hyprland/wm.lua (deep-merged over defaults).
return {
    input = {
        sensitivity  = ${f(root.sensitivity)},
        follow_mouse = ${root.followMouse},
        repeat_delay = ${root.repeatDelay},
        repeat_rate  = ${root.repeatRate},
        touchpad = {
            natural_scroll       = ${b(root.naturalScroll)},
            disable_while_typing = ${b(root.disableWhileTyping)},
            clickfinger_behavior = ${b(root.clickfinger)},
            scroll_factor        = ${f(root.scrollFactor)},
        },
    },
    appearance = {
        gaps_in            = ${root.gapsIn},
        gaps_out           = ${root.gapsOut},
        border_size        = ${root.borderSize},
        rounding           = ${root.rounding},
        blur_enabled       = ${b(root.blurEnabled)},
        blur_size          = ${root.blurSize},
        blur_passes        = ${root.blurPasses},
        dim_inactive       = ${b(root.dimInactive)},
        dim_strength       = ${f(root.dimStrength)},
        animations_enabled = ${b(root.animationsEnabled)},
    },
}
`);
    }

    // --- apply live (instant, no reload) ---------------------------------------
    function applyLive() {
        const f = v => v.toFixed(2);
        const cfg = `hl.config({`
            + `input={sensitivity=${f(root.sensitivity)},follow_mouse=${root.followMouse},repeat_delay=${root.repeatDelay},repeat_rate=${root.repeatRate},`
            + `touchpad={natural_scroll=${root.naturalScroll},disable_while_typing=${root.disableWhileTyping},clickfinger_behavior=${root.clickfinger},scroll_factor=${f(root.scrollFactor)}}},`
            + `general={gaps_in=${root.gapsIn},gaps_out=${root.gapsOut},border_size=${root.borderSize}},`
            + `decoration={rounding=${root.rounding},dim_inactive=${root.dimInactive},dim_strength=${f(root.dimStrength)},blur={enabled=${root.blurEnabled},size=${root.blurSize},passes=${root.blurPasses}}},`
            + `animations={enabled=${root.animationsEnabled}}`
            + `})`;
        Quickshell.execDetached(["hyprctl", "eval", cfg]);
    }

    // Debounced so slider drags coalesce into one apply + one file write.
    Timer { id: debounce; interval: 250; repeat: false; onTriggered: { root.applyLive(); root.persist(); } }
    function change() { if (root.loaded) debounce.restart(); }

    // ── Input ───────────────────────────────────────────────────────────────────
    ContentSection {
        icon: "trackpad_input"
        title: Translation.tr("Touchpad")

        ConfigSwitch {
            buttonIcon: "swap_vert"
            text: Translation.tr("Natural scrolling")
            checked: root.naturalScroll
            onCheckedChanged: { if (checked !== root.naturalScroll) { root.naturalScroll = checked; root.change(); } }
        }
        ConfigSwitch {
            buttonIcon: "ads_click"
            text: Translation.tr("Two-finger tap = right click")
            checked: root.clickfinger
            onCheckedChanged: { if (checked !== root.clickfinger) { root.clickfinger = checked; root.change(); } }
        }
        ConfigSwitch {
            buttonIcon: "keyboard"
            text: Translation.tr("Disable while typing")
            checked: root.disableWhileTyping
            onCheckedChanged: { if (checked !== root.disableWhileTyping) { root.disableWhileTyping = checked; root.change(); } }
        }
        ConfigSlider {
            buttonIcon: "mouse"
            text: Translation.tr("Scroll speed")
            from: 0.1; to: 2.0; value: root.scrollFactor
            onValueChanged: { if (Math.abs(value - root.scrollFactor) > 0.001) { root.scrollFactor = value; root.change(); } }
        }
    }

    ContentSection {
        icon: "tune"
        title: Translation.tr("Pointer & keyboard")

        ConfigSlider {
            buttonIcon: "speed"
            text: Translation.tr("Sensitivity")
            from: -1.0; to: 1.0; value: root.sensitivity
            onValueChanged: { if (Math.abs(value - root.sensitivity) > 0.001) { root.sensitivity = value; root.change(); } }
        }
        ConfigSpinBox {
            icon: "ads_click"
            text: Translation.tr("Focus follows mouse")
            value: root.followMouse; from: 0; to: 3; stepSize: 1
            onValueChanged: { if (value !== root.followMouse) { root.followMouse = value; root.change(); } }
        }
        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            wrapMode: Text.Wrap
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colSubtext
            text: Translation.tr("0 off · 1 full · 2 loose · 3 strict")
        }
        ConfigRow {
            ConfigSpinBox {
                icon: "timer"
                text: Translation.tr("Repeat delay (ms)")
                value: root.repeatDelay; from: 150; to: 600; stepSize: 25
                onValueChanged: { if (value !== root.repeatDelay) { root.repeatDelay = value; root.change(); } }
            }
            ConfigSpinBox {
                icon: "keyboard_double_arrow_right"
                text: Translation.tr("Repeat rate")
                value: root.repeatRate; from: 15; to: 80; stepSize: 5
                onValueChanged: { if (value !== root.repeatRate) { root.repeatRate = value; root.change(); } }
            }
        }
    }

    // ── Appearance ────────────────────────────────────────────────────────────────
    ContentSection {
        icon: "wallpaper"
        title: Translation.tr("Gaps & borders")

        ConfigRow {
            ConfigSpinBox {
                icon: "width"
                text: Translation.tr("Inner gaps")
                value: root.gapsIn; from: 0; to: 40; stepSize: 1
                onValueChanged: { if (value !== root.gapsIn) { root.gapsIn = value; root.change(); } }
            }
            ConfigSpinBox {
                icon: "fit_screen"
                text: Translation.tr("Outer gaps")
                value: root.gapsOut; from: 0; to: 60; stepSize: 1
                onValueChanged: { if (value !== root.gapsOut) { root.gapsOut = value; root.change(); } }
            }
        }
        ConfigRow {
            ConfigSpinBox {
                icon: "border_style"
                text: Translation.tr("Border size")
                value: root.borderSize; from: 0; to: 10; stepSize: 1
                onValueChanged: { if (value !== root.borderSize) { root.borderSize = value; root.change(); } }
            }
            ConfigSpinBox {
                icon: "rounded_corner"
                text: Translation.tr("Window rounding")
                value: root.rounding; from: 0; to: 40; stepSize: 1
                onValueChanged: { if (value !== root.rounding) { root.rounding = value; root.change(); } }
            }
        }
    }

    ContentSection {
        icon: "blur_on"
        title: Translation.tr("Blur & effects")

        ConfigSwitch {
            buttonIcon: "blur_on"
            text: Translation.tr("Blur")
            checked: root.blurEnabled
            onCheckedChanged: { if (checked !== root.blurEnabled) { root.blurEnabled = checked; root.change(); } }
        }
        ConfigRow {
            enabled: root.blurEnabled
            ConfigSpinBox {
                icon: "lens_blur"
                text: Translation.tr("Blur size")
                value: root.blurSize; from: 1; to: 20; stepSize: 1
                onValueChanged: { if (value !== root.blurSize) { root.blurSize = value; root.change(); } }
            }
            ConfigSpinBox {
                icon: "layers"
                text: Translation.tr("Blur passes")
                value: root.blurPasses; from: 1; to: 5; stepSize: 1
                onValueChanged: { if (value !== root.blurPasses) { root.blurPasses = value; root.change(); } }
            }
        }
        ConfigSwitch {
            buttonIcon: "brightness_medium"
            text: Translation.tr("Dim inactive windows")
            checked: root.dimInactive
            onCheckedChanged: { if (checked !== root.dimInactive) { root.dimInactive = checked; root.change(); } }
        }
        ConfigSlider {
            buttonIcon: "brightness_low"
            text: Translation.tr("Dim strength")
            from: 0.0; to: 0.5; value: root.dimStrength
            enabled: root.dimInactive
            onValueChanged: { if (Math.abs(value - root.dimStrength) > 0.001) { root.dimStrength = value; root.change(); } }
        }
        ConfigSwitch {
            buttonIcon: "animation"
            text: Translation.tr("Animations")
            checked: root.animationsEnabled
            onCheckedChanged: { if (checked !== root.animationsEnabled) { root.animationsEnabled = checked; root.change(); } }
        }
    }
}
