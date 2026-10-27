-- Your personal keybinds, ported from the pre-migration ~/.config/hypr/user.lua.
-- Loaded last (see hyprland.lua) so these win over the cachyos-noctalia defaults.
-- Ryoku-shell-only actions (visualizer, stash) are dropped; ryoku commands are
-- retargeted to noctalia or the self-contained scripts under hypr/scripts.

local mod  = "SUPER"
local HOME = os.getenv("HOME")
local SCRIPTS      = HOME .. "/.config/hypr/scripts"
local launch_first = HOME .. "/.local/bin/launch-first.sh"
local special      = HOME .. "/.local/bin/special-toggle.sh"
local noct         = "noctalia msg "

local function launch(...)
    local parts = { ... }
    for i, p in ipairs(parts) do parts[i] = "'" .. p .. "'" end
    return launch_first .. " " .. table.concat(parts, " ")
end

local function zoom(step)
    return function()
        local z = hl.get_config("cursor:zoom_factor") + step
        if z > 3.0 then z = 3.0 elseif z < 1.0 then z = 1.0 end
        hl.config({ cursor = { zoom_factor = z } })
    end
end

hl.config({ input = { follow_mouse = 1 } })

-- Clear the cachyos-noctalia defaults for every chord reclaimed below
-- (hl.bind APPENDS, so an un-unbound chord would fire both actions).
for _, chord in ipairs({
    mod .. " + T", "CTRL + ALT + T", mod .. " + W", mod .. " + C", mod .. " + X",
    mod .. " + E", "CTRL + " .. mod .. " + V", mod .. " + V", "CTRL + SHIFT + Escape",
    "CTRL + SHIFT + W", mod .. " + SHIFT + ALT + Q", mod .. " + D", mod .. " + ALT + F",
    mod .. " + ALT + Space", mod .. " + BracketLeft", mod .. " + BracketRight",
    mod .. " + Semicolon", mod .. " + Apostrophe", "ALT + F4",
    mod .. " + CTRL + Left", mod .. " + CTRL + Right", mod .. " + Page_Up", mod .. " + Page_Down",
    mod .. " + SHIFT + Page_Up", mod .. " + SHIFT + Page_Down",
    mod .. " + CTRL + SHIFT + Left", mod .. " + CTRL + SHIFT + Right",
    mod .. " + S", mod .. " + ALT + S", "CTRL + " .. mod .. " + S",
    mod .. " + ALT + P", "CTRL + " .. mod .. " + P", mod .. " + M", "CTRL + " .. mod .. " + M",
    mod .. " + Minus", mod .. " + Equal", mod .. " + ALT + T",
    mod .. " + A", mod .. " + I", mod .. " + N", mod .. " + G", mod .. " + B",
    mod .. " + SHIFT + R", mod .. " + ALT + R", "CTRL + Print", mod .. " + SHIFT + S",
    mod .. " + SHIFT + L", "CTRL + SHIFT + ALT + " .. mod .. " + Delete",
    mod .. " + SHIFT + P", mod .. " + SHIFT + N", mod .. " + SHIFT + B",
    mod .. " + SHIFT + M", mod .. " + ALT + M", mod .. " + Y", mod .. " + CTRL + T",
    mod .. " + ALT + N", mod .. " + CTRL + A",
    mod .. " + ALT + Left", mod .. " + ALT + Right", mod .. " + ALT + Up", mod .. " + ALT + Down",
}) do hl.unbind(chord) end

-- Apps
hl.bind(mod .. " + T",        hl.dsp.exec_cmd("kitty"))
hl.bind("CTRL + ALT + T",     hl.dsp.exec_cmd("kitty"))
hl.bind(mod .. " + W",        hl.dsp.exec_cmd(launch("zen", "zen-browser", "helium-browser", "chromium", "brave", "firefox")))
hl.bind(mod .. " + C",        hl.dsp.exec_cmd(launch("windsurf", "code", "codium", "cursor", "zed", "kate", "kitty -e micro")))
hl.bind(mod .. " + ALT + N",  hl.dsp.exec_cmd(launch("windsurf", "code", "codium", "cursor", "zed", "kate", "kitty -e micro")))
hl.bind(mod .. " + X",        hl.dsp.exec_cmd(launch("kate", "gnome-text-editor", "kitty -e micro")))
hl.bind(mod .. " + E",        hl.dsp.exec_cmd(launch("dolphin", "nautilus", "thunar", "pcmanfm")))
hl.bind("CTRL + " .. mod .. " + V", hl.dsp.exec_cmd(launch("pavucontrol-qt", "pavucontrol")))
hl.bind(mod .. " + V",        hl.dsp.exec_cmd(noct .. "panel-toggle clipboard"))
hl.bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd(launch("plasma-systemmonitor", "gnome-system-monitor", "kitty -e btop")))

-- Windows
hl.bind("CTRL + SHIFT + W",          hl.dsp.window.close())
hl.bind(mod .. " + SHIFT + ALT + Q", hl.dsp.exec_cmd("hyprctl kill"))
hl.bind(mod .. " + D",               hl.dsp.window.fullscreen_state({ internal = 2, client = 0, action = "toggle" }))
hl.bind(mod .. " + ALT + F",         hl.dsp.window.fullscreen_state({ internal = 0, client = 3, action = "toggle" }))
hl.bind(mod .. " + ALT + Space",     hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + BracketLeft",     hl.dsp.focus({ direction = "l" }))
hl.bind(mod .. " + BracketRight",    hl.dsp.focus({ direction = "r" }))
hl.bind(mod .. " + Semicolon",       hl.dsp.layout("splitratio -0.1"), { repeating = true })
hl.bind(mod .. " + Apostrophe",      hl.dsp.layout("splitratio +0.1"), { repeating = true })
hl.bind(mod .. " + CTRL + A",        function()
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
    hl.dispatch(hl.dsp.window.resize({ x = 1000, y = 660, exact = true }))
    hl.dispatch(hl.dsp.window.center())
end)
hl.bind(mod .. " + ALT + Left",  hl.dsp.window.resize({ x = -40, y = 0,   relative = true }), { repeating = true })
hl.bind(mod .. " + ALT + Right", hl.dsp.window.resize({ x = 40,  y = 0,   relative = true }), { repeating = true })
hl.bind(mod .. " + ALT + Up",    hl.dsp.window.resize({ x = 0,   y = -40, relative = true }), { repeating = true })
hl.bind(mod .. " + ALT + Down",  hl.dsp.window.resize({ x = 0,   y = 40,  relative = true }), { repeating = true })
hl.bind("ALT + F4", hl.dsp.exec_cmd(
    "notify-send 'Wrong close keybind' 'CTRL+SHIFT+W to close. Alt+F4 is for Windows VMs.' -a Hyprland"),
    { non_consuming = true })

-- Workspaces
for i = 1, 10 do
    local key = i % 10
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.exec_cmd(SCRIPTS .. "/ryoku-workspace move " .. i))
end
hl.bind(mod .. " + CTRL + Left",          hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mod .. " + CTRL + Right",         hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mod .. " + Page_Up",              hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mod .. " + Page_Down",            hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mod .. " + SHIFT + Page_Up",      hl.dsp.window.move({ workspace = "m-1" }))
hl.bind(mod .. " + SHIFT + Page_Down",    hl.dsp.window.move({ workspace = "m+1" }))
hl.bind(mod .. " + CTRL + SHIFT + Left",  hl.dsp.window.move({ workspace = "m-1", follow = false }))
hl.bind(mod .. " + CTRL + SHIFT + Right", hl.dsp.window.move({ workspace = "m+1", follow = false }))

-- Special workspaces
hl.bind(mod .. " + S",              hl.dsp.workspace.toggle_special("stash"))
hl.bind(mod .. " + ALT + S",        hl.dsp.window.move({ workspace = "special:stash", follow = false }))
hl.bind(mod .. " + SHIFT + S",      hl.dsp.window.move({ workspace = "m+0" }))
hl.bind("CTRL + " .. mod .. " + S", hl.dsp.exec_cmd(special .. " stash"))
hl.bind(mod .. " + ALT + P",        hl.dsp.workspace.toggle_special("private"))
hl.bind("CTRL + " .. mod .. " + P", hl.dsp.exec_cmd(special .. " private"))
hl.bind(mod .. " + M",              hl.dsp.exec_cmd(special .. " minimized"))
hl.bind("CTRL + " .. mod .. " + M", hl.dsp.workspace.toggle_special("minimized"))

-- Screen
hl.bind(mod .. " + Minus",   zoom(-0.3), { repeating = true })
hl.bind(mod .. " + Equal",   zoom( 0.3), { repeating = true })
hl.bind(mod .. " + ALT + T", hl.dsp.exec_cmd(HOME .. "/.local/bin/toggle-touchscreen"))

-- Shell surfaces (noctalia)
hl.bind(mod .. " + A", hl.dsp.exec_cmd(noct .. "panel-toggle control-center"))
hl.bind(mod .. " + I", hl.dsp.exec_cmd(noct .. "settings-toggle"))
hl.bind(mod .. " + N", hl.dsp.exec_cmd(SCRIPTS .. "/ryoku-workspace focus 10"))
hl.bind(mod .. " + B", hl.dsp.exec_cmd(noct .. "wallpaper-next"))
hl.bind(mod .. " + CTRL + T", hl.dsp.exec_cmd(noct .. "panel-toggle wallpaper"))
hl.bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd(SCRIPTS .. "/ryoku-cmd-screenrecord --fullscreen"), { locked = true })
hl.bind(mod .. " + ALT + R",   hl.dsp.exec_cmd(SCRIPTS .. "/ryoku-cmd-screenrecord --region"),     { locked = true })

hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd("/home/sitish/.local/bin/screenshot-copy area"))
hl.bind("SHIFT + Print",       hl.dsp.exec_cmd("/home/sitish/.local/bin/screenshot-snip area"))

hl.bind("CTRL + Print", hl.dsp.exec_cmd("/home/sitish/.local/bin/screenshot-copy output"),
    { locked = true, non_consuming = true })

-- Session
hl.bind(mod .. " + SHIFT + L", hl.dsp.exec_cmd(noct .. "session lock-and-suspend"), { locked = true })
hl.bind("CTRL + SHIFT + ALT + " .. mod .. " + Delete", hl.dsp.exec_cmd("systemctl poweroff"))

-- Media
hl.bind(mod .. " + SHIFT + P", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind(mod .. " + SHIFT + N", hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind(mod .. " + SHIFT + B", hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
hl.bind(mod .. " + SHIFT + M", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),   { locked = true })
hl.bind(mod .. " + ALT + M",   hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
