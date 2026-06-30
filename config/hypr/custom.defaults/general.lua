-- ═══════════════════════════════════════════════════════════════════════════
-- General config — this file is the COMPLETE general config for your setup.
-- Edit freely here. When this file exists, hyprland/general.lua is skipped.
-- Updates never touch this file. Check hyprland/general.lua after an update
-- for any new settings added upstream and copy what you want here.
-- ═══════════════════════════════════════════════════════════════════════════

-- MONITOR CONFIG
-- Default: native resolution/refresh + auto scale. Specific monitor overrides
-- are written by Settings > Display to custom/display.lua (loaded after this).
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = "auto"
})

-- Gestures
-- 3-finger "move window" is conditional below (disabled when hyprtasking is active).
-- 4-finger horizontal: switch workspaces
hl.gesture({
    fingers = 4,
    direction = "horizontal",
    action = "workspace"
})

hl.config({
    gestures = {
        workspace_swipe_distance = 700,
        workspace_swipe_cancel_ratio = 0.2,
        workspace_swipe_min_speed_to_force = 5,
        workspace_swipe_direction_lock = true,
        workspace_swipe_direction_lock_threshold = 10,
        workspace_swipe_create_new = true
    },
    general = {
        gaps_in = 2,
        gaps_out = 4,
        gaps_workspaces = 50,

        border_size = 1,

        col = {
            active_border = "rgba(0DB7D455)",
            inactive_border = "rgba(31313600)"
        },
        resize_on_border = true,

        no_focus_fallback = true,
        allow_tearing = true,
        snap = {
            enabled = true,
            window_gap = 4,
            monitor_gap = 5,
            respect_gaps = true
        }
    },
    decoration = {
        rounding_power = 2.5,
        rounding = 18,

        blur = {
            enabled = true,
            xray = true,
            special = false,
            new_optimizations = true,
            size = 10,
            passes = 3,
            brightness = 1,
            noise = 0.05,
            contrast = 0.89,
            vibrancy = 0.5,
            vibrancy_darkness = 0.5,
            popups = false,
            popups_ignorealpha = 0.6,
            input_methods = true,
            input_methods_ignorealpha = 0.8
        },
        shadow = {
            enabled = true,
            range = 20,
            offset = {0, 2},
            render_power = 10,
            color = "rgba(00000020)"
        },
        dim_inactive = true,
        dim_strength = 0.05,
        dim_special = 0.2
    },
    animations = {
        enabled = true
    },
    dwindle = {
        preserve_split = true,
        smart_split = false,
        smart_resizing = false
    },
})

-- Bezier curves
hl.curve("expressiveFastSpatial",    { type = "bezier", points = {{0.42, 1.67}, {0.21, 0.90}} })
hl.curve("expressiveSlowSpatial",    { type = "bezier", points = {{0.39, 1.29}, {0.35, 0.98}} })
hl.curve("expressiveDefaultSpatial", { type = "bezier", points = {{0.38, 1.21}, {0.22, 1.00}} })
hl.curve("emphasizedDecel",          { type = "bezier", points = {{0.05, 0.7},  {0.1,  1}}    })
hl.curve("emphasizedAccel",          { type = "bezier", points = {{0.3,  0},    {0.8,  0.15}} })
hl.curve("standardDecel",            { type = "bezier", points = {{0,    0},    {0,    1}}    })
hl.curve("menu_decel",               { type = "bezier", points = {{0.1,  1},    {0,    1}}    })
hl.curve("menu_accel",               { type = "bezier", points = {{0.52, 0.03}, {0.72, 0.08}} })
hl.curve("stall",                    { type = "bezier", points = {{1,    -0.1}, {0.7,  0.85}} })

-- Animations
hl.animation({ leaf = "windowsIn",           enabled = true, speed = 3,   bezier = "emphasizedDecel", style = "popin 80%"   })
hl.animation({ leaf = "fadeIn",              enabled = true, speed = 3,   bezier = "emphasizedDecel"                        })
hl.animation({ leaf = "windowsOut",          enabled = true, speed = 2,   bezier = "emphasizedDecel", style = "popin 90%"   })
hl.animation({ leaf = "fadeOut",             enabled = true, speed = 2,   bezier = "emphasizedDecel"                        })
hl.animation({ leaf = "windowsMove",         enabled = true, speed = 3,   bezier = "emphasizedDecel", style = "slide"       })
hl.animation({ leaf = "border",              enabled = true, speed = 10,  bezier = "emphasizedDecel"                        })
hl.animation({ leaf = "layersIn",            enabled = true, speed = 2.7, bezier = "emphasizedDecel", style = "popin 93%"   })
hl.animation({ leaf = "layersOut",           enabled = true, speed = 2.4, bezier = "menu_accel",      style = "popin 94%"   })
hl.animation({ leaf = "fadeLayersIn",        enabled = true, speed = 0.5, bezier = "menu_decel"                             })
hl.animation({ leaf = "fadeLayersOut",       enabled = true, speed = 2.7, bezier = "stall"                                  })
hl.animation({ leaf = "workspaces",          enabled = true, speed = 7,   bezier = "menu_decel",      style = "slide"       })
hl.animation({ leaf = "specialWorkspaceIn",  enabled = true, speed = 2.8, bezier = "emphasizedDecel", style = "slidevert"   })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 1.2, bezier = "emphasizedAccel", style = "slidevert"   })
hl.animation({ leaf = "zoomFactor",          enabled = true, speed = 3,   bezier = "standardDecel"                          })

hl.config({
    input = {
        kb_layout = "us",
        numlock_by_default = true,
        repeat_delay = 250,
        repeat_rate = 35,

        follow_mouse = 1,
        off_window_axis_events = 2,

        touchpad = {
            natural_scroll = true,
            disable_while_typing = true,
            clickfinger_behavior = true,
            scroll_factor = 0.7
        }
    },

    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        vrr = 1,
        mouse_move_enables_dpms = true,
        key_press_enables_dpms = true,
        animate_manual_resizes = false,
        animate_mouse_windowdragging = false,
        enable_swallow = false,
        swallow_regex = "(foot|kitty|allacritty|Alacritty)",
        on_focus_under_fullscreen = 2,
        allow_session_lock_restore = true,
        session_lock_xray = true,
        initial_workspace_tracking = false,
        focus_on_activate = true
    },

    binds = {
        scroll_event_delay = 0,
        hide_special_on_workspace_change = true
    },

    cursor = {
        zoom_factor = 1,
        zoom_rigid = false,
        zoom_disable_aa = true,
        hotspot_padding = 1
    },

    xwayland = {
        force_zero_scaling = true
    }
})

-- ═══════════════════════════════════════════════════════════════════════════
-- Custom additions — add your changes below
-- ═══════════════════════════════════════════════════════════════════════════

-- ───────────────────────────────────────────────────────────────────────────
-- Overview plugin (hyprtasking fork)
-- Our hyprtasking fork is the one overview plugin (loaded/unloaded by
-- custom/scripts/overview-switch.sh). This block reads custom/overview.state and,
-- when the plugin is active, applies its config + wires the 4-finger-up swipe.
-- "none" (overview off) skips it entirely. SUPER+Tab always opens the quickshell
-- overview (see custom/keybinds.lua). Everything is pcall-guarded so an
-- unloaded plugin can't break config.
-- ───────────────────────────────────────────────────────────────────────────
local function _read_overview_state()
    local f = io.open(HOME .. "/.config/hypr/custom/overview.state", "r")
    if not f then return "hyprtasking" end
    local s = f:read("l")
    f:close()
    if not s or s == "" then return "hyprtasking" end
    return (s:gsub("%s+", ""))
end

local _active_overview = _read_overview_state()

-- Guard on the plugin actually being loaded (hl.plugin.hyprtasking is nil otherwise).
-- Setting plugin:* config keys for an unloaded plugin raises a config-error overlay
-- that pcall cannot catch, so we must not reach it at all.
if _active_overview == "hyprtasking" and hl.plugin and hl.plugin.hyprtasking then
    pcall(function()
        hl.config({ plugin = { hyprtasking = {
            layout = "grid",
            gap_size = 10,
            exit_on_hovered = true,
            rounding = 14,
            plus_on_empty = true,
            focus_follows_cursor = true,
            blur_bg = true,
            bg_color = 0x00000066,
            grid = {
                adaptive = true,
                rows = 3,
                cols = 4,
                loop = true,
            },
            gestures = {
                enabled = true,
                open_fingers = 4,
                open_distance = 120,
                open_positive = true,
                move_fingers = 3,
                move_distance = 300,
            },
        } } })
    end)
end

-- 3-finger "move window" gesture: disabled while hyprtasking is active
-- (hyprtasking uses 3-finger to navigate workspaces).
if _active_overview ~= "hyprtasking" then
    pcall(function()
        hl.gesture({ fingers = 3, direction = "swipe", action = "move" })
    end)
end
