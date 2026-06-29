hl.bind("CTRL+SUPER+ALT+Slash", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"), {description = "Edit user keybinds"} )

hl.bind("SUPER + B", hl.dsp.exec_cmd("chromium"), { description = "Helium Browser" })

hl.bind("SUPER+H", hl.dsp.exec_cmd("chromium"), { description = "Helium" })

hl.bind(
    "SUPER+ALT+T",
    hl.dsp.exec_cmd("~/.local/bin/toggle-touchscreen"),
    { description = "Toggle Touchscreen" }
)

-- Overview (hyprtasking fork): the 4-finger-up swipe opens it; these toggle it on/off.
local _ovsw = "~/.config/hypr/custom/scripts/overview-switch.sh "
hl.bind("SUPER + CTRL + 1", hl.dsp.exec_cmd(_ovsw .. "hyprtasking"), { description = "Overview: hyprtasking (adaptive grid)" })
hl.bind("SUPER + CTRL + 0", hl.dsp.exec_cmd(_ovsw .. "off"),         { description = "Overview: disable plugin" })
hl.bind("SUPER + grave",    hl.dsp.exec_cmd(_ovsw .. "toggle"),      { description = "Overview: open/close" })

-- Super + Space: toggle the workspace overview. (Tap Super alone already opens
-- the app launcher via the ii SUPER+SUPER_L search binding.)
hl.bind("SUPER + Space", hl.dsp.exec_cmd("~/.config/hypr/custom/scripts/overview-switch.sh toggle"), { description = "Overview: toggle workspace overview" })
