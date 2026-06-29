-- Portable default: every output uses its NATIVE mode + an auto-picked scale, so this
-- adapts per machine instead of forcing one laptop's panel. On this 2880x1800@120
-- laptop "preferred" still resolves to 2880x1800@120. To pin a specific machine, set
-- e.g. monitor = "eDP-1,2880x1800@120,auto,1.5" (but keep that out of the shared repo).
monitor = ",preferred,auto,auto"

-- ───────────────────────────────────────────────────────────────────────────
-- Overview plugin switcher
-- Exactly one overview plugin is enabled at a time (managed by
-- custom/scripts/overview-switch.sh). This block reads custom/overview.state
-- and points the 4-finger-up swipe at whichever plugin is active.
-- SUPER+Tab always opens the quickshell overview (see custom/keybinds.lua).
-- Everything is pcall-guarded so a disabled/unloaded plugin can't break config.
-- ───────────────────────────────────────────────────────────────────────────
local function _read_overview_state()
    local f = io.open(HOME .. "/.config/hypr/custom/overview.state", "r")
    if not f then return "scrolloverview" end
    local s = f:read("l")
    f:close()
    if not s or s == "" then return "scrolloverview" end
    return (s:gsub("%s+", ""))
end

local _active_overview = _read_overview_state()

-- Guard each block on the plugin actually being loaded (hl.plugin.<name> is nil
-- otherwise). Setting plugin:* config keys for an unloaded plugin raises a
-- config-error overlay that pcall cannot catch, so we must not reach it at all.
if _active_overview == "scrolloverview" and hl.plugin and hl.plugin.scrolloverview then
    pcall(function()
        hl.config({ plugin = { scrolloverview = {
            layout = "vertical",     -- niri-classic: workspaces stacked top-to-bottom
            scale = 0.6,
            workspace_gap = 80,
            gesture_distance = 300,  -- how far the swipe tracks your fingers
            wallpaper = 2,           -- 0 global only, 1 per-workspace, 2 both (filled)
            blur = true,             -- blur the main overview background wallpaper
            input = {
                scroll_event_delay = 30,  -- debounce; lower = snappier workspace steps
                scrolling_mode = 2,       -- vertical scroll = workspaces, horizontal = columns
                drag_mode = 0,            -- middle-button drag = continuous pan
            },
        } } })
        hl.plugin.scrolloverview.gesture({ fingers = 4, direction = "up" })   -- swipe up to open
        hl.plugin.scrolloverview.gesture({ fingers = 4, direction = "down" }) -- swipe down to close/zoom in
    end)
elseif _active_overview == "hyprtasking" and hl.plugin and hl.plugin.hyprtasking then
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
-- Hyprspace intentionally dropped: it builds but CRASHES on Hyprland 0.55.4
-- (config key plugin:overview:* never registers). The switcher refuses it.
end

-- ii's native 3-finger "move window" (drag-tile) gesture lives here so it can be
-- turned OFF while hyprtasking is active — hyprtasking uses 3-finger to navigate
-- workspaces. (It's commented out in hyprland/general.lua.) Active for every
-- other mode (scrolloverview / none).
if _active_overview ~= "hyprtasking" then
    pcall(function()
        hl.gesture({ fingers = 3, direction = "swipe", action = "move" })
    end)
end
