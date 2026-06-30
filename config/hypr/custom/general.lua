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
            layout = "grid",         -- "linear" = single scrollable strip (niri-like)
            gap_size = 10,
            exit_on_hovered = true,  -- close lands on the workspace under the cursor
            -- FORK-ONLY keys below. These persist in config so every trigger
            -- (gesture / keybind) opens the same overview; the fork is the only
            -- hyprtasking the switcher loads, so they're always valid. Guarded
            -- by `hl.plugin.hyprtasking` above for when nothing is loaded.
            rounding = 14,           -- rounded tile corners
            plus_on_empty = true,    -- "+" on empty create cells
            focus_follows_cursor = true,
            blur_bg = true,          -- blurred wallpaper background
            bg_color = 0x00000066,   -- translucent so the blurred wallpaper shows
            grid = {
                adaptive = true,     -- square grid sized by highest workspace number
                rows = 3,
                cols = 4,            -- fallback when adaptive = false
                loop = true,
            },
            gestures = {
                enabled = true,
                open_fingers = 4,
                open_distance = 120,   -- shorter = a small flick opens (was 300)
                open_positive = true,  -- swipe UP opens
                -- 3-finger swipe navigates workspaces in the overview. ii's
                -- native 3-finger "move window" gesture is disabled while
                -- hyprtasking is active (conditional block at end of file).
                move_fingers = 3,
                move_distance = 300,
            },
        } } })
    end)
end

-- ii's native 3-finger "move window" (drag-tile) gesture lives here so it can be
-- turned OFF while hyprtasking is active — hyprtasking uses 3-finger to navigate
-- workspaces. (It's commented out in hyprland/general.lua.) Active when the overview
-- plugin is off ("none").
if _active_overview ~= "hyprtasking" then
    pcall(function()
        hl.gesture({ fingers = 3, direction = "swipe", action = "move" })
    end)
end
