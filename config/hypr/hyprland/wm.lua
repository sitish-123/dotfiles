-- ═══════════════════════════════════════════════════════════════════════════
-- Window Manager settings — APPLY LOGIC (tracked; don't edit for settings)
-- ═══════════════════════════════════════════════════════════════════════════
-- GUI-managed Hyprland input + appearance settings, same data/logic split as
-- hyprtasking. The DATA lives in custom/wm.lua (user/GUI-owned, seeded from
-- custom.defaults/wm.lua); this file deep-merges it over the defaults below (which
-- mirror general.lua's shipped values) and applies it. Sourced AFTER general.lua so
-- the GUI-managed subset wins; everything general.lua sets that the GUI doesn't touch
-- is left alone.
--   • Tweak from the GUI: Settings > Window Manager (writes custom/wm.lua).
--   • Or edit custom/wm.lua directly. Missing keys fall back to the defaults here.
-- ═══════════════════════════════════════════════════════════════════════════

local defaults = {
    input = {
        sensitivity  = 0,      -- -1.0 .. 1.0
        follow_mouse = 1,      -- 0 none, 1 full, 2 loose, 3 strict
        repeat_delay = 250,
        repeat_rate  = 35,
        touchpad = {
            natural_scroll       = true,
            disable_while_typing = false,
            clickfinger_behavior = true,
            scroll_factor        = 0.7,
        },
    },
    appearance = {
        gaps_in            = 2,
        gaps_out           = 4,
        border_size        = 1,
        rounding           = 18,
        blur_enabled       = true,
        blur_size          = 10,
        blur_passes        = 3,
        dim_inactive       = true,
        dim_strength       = 0.05,
        animations_enabled = true,
    },
}

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
    local ok, user = pcall(require, "custom.wm")
    if ok and type(user) == "table" then M = merge(defaults, user) end
end

pcall(function()
    hl.config({
        input = {
            sensitivity  = M.input.sensitivity,
            follow_mouse = M.input.follow_mouse,
            repeat_delay = M.input.repeat_delay,
            repeat_rate  = M.input.repeat_rate,
            touchpad = {
                natural_scroll         = M.input.touchpad.natural_scroll,
                disable_while_typing   = M.input.touchpad.disable_while_typing,
                clickfinger_behavior   = M.input.touchpad.clickfinger_behavior,
                scroll_factor          = M.input.touchpad.scroll_factor,
            },
        },
        general = {
            gaps_in     = M.appearance.gaps_in,
            gaps_out    = M.appearance.gaps_out,
            border_size = M.appearance.border_size,
        },
        decoration = {
            rounding     = M.appearance.rounding,
            dim_inactive = M.appearance.dim_inactive,
            dim_strength = M.appearance.dim_strength,
            blur = {
                enabled = M.appearance.blur_enabled,
                size    = M.appearance.blur_size,
                passes  = M.appearance.blur_passes,
            },
        },
        animations = {
            enabled = M.appearance.animations_enabled,
        },
    })
end)

return M
