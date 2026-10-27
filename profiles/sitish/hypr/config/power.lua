-- battery: 60Hz, no blur, opaque windows. power-mode-watch reloads the config on plug/unplug.
local f = io.open("/sys/class/power_supply/BAT0/status")
local on_battery = f and f:read("*l") == "Discharging"
if f then f:close() end

if on_battery then
    hl.monitor({ output = "eDP-1", mode = "2880x1800@60.00", position = "0x0", scale = 1.5 })
    hl.config({ decoration = { active_opacity = 1, inactive_opacity = 1, blur = { enabled = false } } })
end
