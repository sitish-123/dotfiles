-- ═══════════════════════════════════════════════════════════════════════════
-- Hyprtasking overview — APPLY LOGIC (tracked shipped default; don't edit for settings)
-- ═══════════════════════════════════════════════════════════════════════════
-- Settings live in a DATA file the user (and the GUI Settings app) own:
--     custom/hyprtasking.lua   -> a plain `return { ... }` table
-- seeded once from custom.defaults/hyprtasking.lua (never overwritten). This file only
-- MERGES that data over the built-in defaults below and applies it — config, gestures,
-- keybinds, and the login auto-restore. Keeping logic here (tracked) and data in custom/
-- (gitignored, GUI-writable) means the GUI only ever rewrites a data table, and a fresh
-- install is never left without working settings.
--
--   • Tweak settings   → edit custom/hyprtasking.lua (or the GUI).
--   • Disable entirely → set `enabled = false` there (plugin won't load / bind;
--                        the 3-finger "move window" gesture is restored).
--
-- Runtime load/unload is done by custom/scripts/overview-switch.sh, which records the
-- active overview in custom/overview.state. We only apply plugin:* config when the
-- plugin is actually loaded (those keys for an unloaded plugin raise an uncatchable
-- config-error overlay).
-- ═══════════════════════════════════════════════════════════════════════════

local defaults = {
    enabled = true,
    settings = {
        layout               = "grid",
        gap_size             = 10,
        exit_on_hovered      = true,
        rounding             = 14,
        plus_on_empty        = true,
        focus_follows_cursor = true,
        blur_bg              = true,
        bg_color             = 0x00000066,
        grid = { adaptive = true, rows = 3, cols = 4, loop = true },
    },
    gestures = {
        enabled = true, open_fingers = 4, open_distance = 120,
        open_positive = true, move_fingers = 3, move_distance = 300,
    },
    keybinds = {
        load = "SUPER + CTRL + 1", off = "SUPER + CTRL + 0",
        toggle = "SUPER + grave", toggle2 = "SUPER + Space",
    },
}

-- Deep-merge user data over defaults so an OLD custom file still picks up NEW default
-- keys added by an update (missing keys fall through to the default).
local function merge(base, over)
    if type(over) ~= "table" then return base end
    local out = {}
    for k, v in pairs(base) do out[k] = v end
    for k, v in pairs(over) do
        if type(v) == "table" and type(base[k]) == "table" then out[k] = merge(base[k], v)
        else out[k] = v end
    end
    return out
end

local M = defaults
do
    local ok, user = pcall(require, "custom.hyprtasking")
    if ok and type(user) == "table" then M = merge(defaults, user) end
end

local _ovsw = "~/.config/hypr/custom/scripts/overview-switch.sh "

-- Disabled: bind/load nothing; hand the 3-finger "move window" gesture back.
if not M.enabled then
    pcall(function() hl.gesture({ fingers = 3, direction = "swipe", action = "move" }) end)
    return M
end

-- Keybinds
hl.bind(M.keybinds.load,   hl.dsp.exec_cmd(_ovsw .. "hyprtasking"), { description = "Overview: hyprtasking (adaptive grid)" })
hl.bind(M.keybinds.off,    hl.dsp.exec_cmd(_ovsw .. "off"),         { description = "Overview: disable plugin" })
hl.bind(M.keybinds.toggle, hl.dsp.exec_cmd(_ovsw .. "toggle"),      { description = "Overview: open/close" })
if M.keybinds.toggle2 and M.keybinds.toggle2 ~= "" then
    hl.bind(M.keybinds.toggle2, hl.dsp.exec_cmd(_ovsw .. "toggle"), { description = "Overview: open/close" })
end

-- Login auto-restore (single load → no plugin-reload race).
hl.on("hyprland.start", function() hl.exec_cmd(_ovsw .. "restore") end)

-- Which overview is active right now ("none" = user turned it off at runtime).
local function _read_overview_state()
    local f = io.open(HOME .. "/.config/hypr/custom/overview.state", "r")
    if not f then return "hyprtasking" end
    local s = f:read("l"); f:close()
    if not s or s == "" then return "hyprtasking" end
    return (s:gsub("%s+", ""))
end
local _active = _read_overview_state()

-- Apply plugin config only when the plugin is loaded (see header).
if _active == "hyprtasking" and hl.plugin and hl.plugin.hyprtasking then
    pcall(function()
        hl.config({ plugin = { hyprtasking = {
            layout               = M.settings.layout,
            gap_size             = M.settings.gap_size,
            exit_on_hovered      = M.settings.exit_on_hovered,
            rounding             = M.settings.rounding,
            plus_on_empty        = M.settings.plus_on_empty,
            focus_follows_cursor = M.settings.focus_follows_cursor,
            blur_bg              = M.settings.blur_bg,
            bg_color             = M.settings.bg_color,
            grid                 = M.settings.grid,
            gestures             = M.settings.gestures,
        } } })
    end)
end

-- 3-finger "move window" only when hyprtasking is NOT the active overview.
if _active ~= "hyprtasking" then
    pcall(function() hl.gesture({ fingers = 3, direction = "swipe", action = "move" }) end)
end

return M
