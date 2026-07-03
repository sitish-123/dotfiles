-- ═══════════════════════════════════════════════════════════════════════════
-- Hyprtasking overview — YOUR SETTINGS (edit freely; the GUI Settings app writes here)
-- ═══════════════════════════════════════════════════════════════════════════
-- Plain DATA table consumed by hyprland/hyprtasking.lua (which holds the apply logic).
-- Seeded to custom/hyprtasking.lua on install — ONLY if that file is missing, so your
-- edits are never overwritten. Missing keys fall back to built-in defaults.
--
--   • Turn the overview OFF entirely →  enabled = false
--   • Rebind                          →  keybinds.*
--   • Tune the grid / gestures        →  settings.* / gestures.*
-- ═══════════════════════════════════════════════════════════════════════════
return {
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
        enabled       = true,
        open_enabled  = true,   -- 4-finger up/down: open/close overview
        move_enabled  = true,   -- 3-finger: navigate the grid
        switch_enabled= true,   -- 4-finger left/right: switch workspace
        open_fingers  = 4,
        open_distance = 120,
        open_positive = true,
        move_fingers  = 3,
        move_distance = 300,
    },

    keybinds = {
        load    = "SUPER + CTRL + 1",   -- load the fork overview
        off     = "SUPER + CTRL + 0",   -- unload the overview plugin
        toggle  = "SUPER + grave",      -- open / close
        toggle2 = "SUPER + Space",      -- open / close (alt); set "" to unbind
    },
}
