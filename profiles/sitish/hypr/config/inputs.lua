-- Input configuration

hl.config({
    input = {
        -- sensitivity = -0.25,
        accel_profile = "flat",
    },
    -- Uncomment the section below to enable software cursors; this can help with cursor display or behavior issues
    -- cursor = {
    --     no_hardware_cursors = 1,
    -- },
})

-- Touchpad only (leaves the mouse on the global sensitivity); overrides the
-- global 0.15 from hyprland-gui.lua. sensitivity: -1.0..1.0, higher = faster.
hl.device({ name = "asuf1415:00-2808:0224-touchpad", sensitivity = 0.3, accel_profile = "adaptive" })

hl.gesture({ fingers = 3, direction = "up",         action = "fullscreen" })
hl.gesture({ fingers = 3, direction = "left",       action = "float" })

hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })

-- scrolloverview is loaded by `hyprpm reload` after the first config parse
if hl.plugin.scrolloverview then
    hl.config({ plugin = { scrolloverview = { layout = "horizontal" } } })
    hl.plugin.scrolloverview.gesture({ fingers = 4, direction = "up", action = "overview" })
end
