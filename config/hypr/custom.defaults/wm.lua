-- ═══════════════════════════════════════════════════════════════════════════
-- Window Manager settings — YOUR DATA (edit freely; the GUI Settings app writes here)
-- ═══════════════════════════════════════════════════════════════════════════
-- Plain data table consumed by hyprland/wm.lua (which holds the apply logic). Seeded to
-- custom/wm.lua on install — ONLY if missing, so your edits are never overwritten.
-- Missing keys fall back to built-in defaults, so you can keep just what you care about.
return {
    input = {
        sensitivity  = 0,      -- -1.0 (slow) .. 1.0 (fast)
        follow_mouse = 1,      -- 0 none · 1 full · 2 loose · 3 strict
        repeat_delay = 250,    -- ms before key repeat
        repeat_rate  = 35,     -- repeats/sec
        touchpad = {
            natural_scroll       = true,
            disable_while_typing = false,
            clickfinger_behavior = true,   -- 2-finger = right-click
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
