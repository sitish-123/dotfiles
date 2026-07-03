-- This file sources other files in `hyprland` and `custom` folders
-- You wanna add your stuff in files in `custom`

-- Internal stuff --
require("hyprland.lib")
require("hyprland.services")

-- Environment variables --
require("hyprland.env")
-- User env vars (GUI-managed): logic in hyprland/userenv.lua reads the data table in
-- custom/env.lua and applies it after the shipped vars. pcall-guarded, safe if absent.
require("hyprland.userenv")

-- Default configurations --
require("hyprland.execs")
require("hyprland.rules")
-- colors.lua is matugen-generated from the wallpaper (gitignored, not portable).
-- On a fresh install it doesn't exist yet; guard the require so a missing theme
-- can't trip emergency mode and drop all keybinds. It loads once matugen runs.
if is_file_exists(HOME .. "/.config/hypr/hyprland/colors.lua") then
    require("hyprland.colors")
end

-- Custom configurations --
if is_file_exists(HOME .. "/.config/hypr/custom/execs.lua") then
    require("custom.execs")
end
-- User autostart (GUI-managed): logic in hyprland/autostart.lua runs the enabled
-- commands from the data table in custom/autostart.lua. Separate from custom/execs.lua
-- (critical session bringup) so the GUI never clobbers that. pcall-guarded.
require("hyprland.autostart")
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

-- Hyprtasking overview: single source of truth. Apply logic is here (tracked);
-- it reads settings from custom/hyprtasking.lua (user/GUI-owned, seeded from
-- custom.defaults/) and applies config + gestures + keybinds + login restore.
-- Sourced after keybinds so its binds register cleanly.
if is_file_exists(HOME .. "/.config/hypr/hyprland/hyprtasking.lua") then
    require("hyprland.hyprtasking")
end

-- Window Manager settings (GUI-managed input + appearance). Apply logic is tracked in
-- hyprland/wm.lua; it deep-merges the user/GUI data from custom/wm.lua over its defaults.
-- Sourced after general.lua so the GUI-managed subset wins.
if is_file_exists(HOME .. "/.config/hypr/hyprland/wm.lua") then
    require("hyprland.wm")
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
