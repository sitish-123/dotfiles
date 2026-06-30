-- This file sources other files in `hyprland` and `custom` folders
-- You wanna add your stuff in files in `custom`

-- Internal stuff --
require("hyprland.lib")
require("hyprland.services")

-- Environment variables --
require("hyprland.env")
if is_file_exists(HOME .. "/.config/hypr/custom/env.lua") then
    require("custom.env")
end

-- Default configurations --
require("hyprland.execs")
require("hyprland.rules")
require("hyprland.colors")

-- Custom configurations --
if is_file_exists(HOME .. "/.config/hypr/custom/execs.lua") then
    require("custom.execs")
end
-- General config: custom/general.lua is the complete replacement when present.
-- On a fresh install with no custom/general.lua the shipped defaults load.
if is_file_exists(HOME .. "/.config/hypr/custom/general.lua") then
    require("custom.general")
else
    require("hyprland.general")
end
-- Display overrides written by Settings > Display (monitor mode/scale/transform + VRR).
-- Sourced after general.lua so it wins over any monitor= line there.
if is_file_exists(HOME .. "/.config/hypr/custom/display.lua") then
    require("custom.display")
end
if is_file_exists(HOME .. "/.config/hypr/custom/rules.lua") then
    require("custom.rules")
end
-- Keybinds: custom/keybinds.lua is the complete replacement when present
-- (hyprland/keybinds.lua is skipped to avoid duplicate bindings).
-- On a fresh install with no custom/keybinds.lua the shipped defaults load.
if is_file_exists(HOME .. "/.config/hypr/custom/keybinds.lua") then
    require("custom.keybinds")
else
    require("hyprland.keybinds")
end

-- nwg-displays support --
if is_file_exists(HOME .. "/.config/hypr/workspaces.lua") then
    require("workspaces")
end
if is_file_exists(HOME .. "/.config/hypr/monitors.lua") then
    require("monitors")
end

-- Shell overrides --
require("hyprland.shellOverrides.main")
