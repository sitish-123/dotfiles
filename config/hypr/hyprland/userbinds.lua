-- ═══════════════════════════════════════════════════════════════════════════
-- Keybinds — APPLY ENGINE (tracked; don't edit for settings)
-- ═══════════════════════════════════════════════════════════════════════════
-- GUI-managed keybinds, data/logic split. The DATA is a table of bind entries in
-- custom/keybinds.lua (user/GUI-owned, seeded from custom.defaults/keybinds.lua);
-- this engine binds each one. Every bind is plain data, yet dynamic behavior is
-- preserved via typed action BUILDERS below: group-aware workspace switching
-- (focus_ws_group / move_ws_group → workspace_in_group, evaluated per press), cursor
-- zoom, and the virtual-machine submap all keep working.
--   • Edit from the GUI: Settings > Keybinds (writes custom/keybinds.lua).
--   • Or edit custom/keybinds.lua directly. Entry shape:
--       { mods="SUPER + ALT", key="A", action="exec", arg="…", desc="…",
--         section="Apps", flags={ locked=true, repeating=true, … }, disabled=false }
-- Each bind is pcall-guarded: one bad entry can never drop the rest or trip
-- emergency mode. Sourced instead of custom.keybinds when the data table is present.
-- ═══════════════════════════════════════════════════════════════════════════

require("hyprland.lib") -- workspace_in_group, is_file_exists, HOME
if is_file_exists(HOME .. "/.config/hypr/custom/variables.lua") then
    require("custom.variables")
else
    require("hyprland.variables")
end

-- cursor zoom (was an inline helper in the old keybinds.lua)
local function zoomfunction(value)
    local z = hl.get_config("cursor:zoom_factor")
    local nz = z + value
    if nz > 3.0 then nz = 3.0 elseif nz < 1.0 then nz = 1.0 end
    hl.config({ cursor = { zoom_factor = nz } })
end

-- action name -> builder(arg) -> a dispatcher or a plain function
local B = {
    exec           = function(a) return hl.dsp.exec_cmd(a) end,
    global         = function(a) return hl.dsp.global(a) end,
    focus_ws       = function(a) return hl.dsp.focus({ workspace = a }) end,
    focus_dir      = function(a) return hl.dsp.focus({ direction = a }) end,
    move_ws        = function(a) return hl.dsp.window.move({ workspace = a }) end,
    move_ws_nf     = function(a) return hl.dsp.window.move({ workspace = a, follow = false }) end,
    move_dir       = function(a) return hl.dsp.window.move({ direction = a }) end,
    drag           = function() return hl.dsp.window.drag() end,
    resize         = function() return hl.dsp.window.resize() end,
    resize_exact   = function(a)
        local x, y = tostring(a):match("(%-?%d+)%s+(%-?%d+)")
        return hl.dsp.window.resize({ x = tonumber(x) or 640, y = tonumber(y) or 480, "exact" })
    end,
    close          = function() return hl.dsp.window.close() end,
    float          = function() return hl.dsp.window.float({ action = "toggle" }) end,
    fullscreen     = function(a) return hl.dsp.window.fullscreen({ mode = (a ~= "" and a) or "fullscreen", action = "toggle" }) end,
    fs_state       = function() return hl.dsp.window.fullscreen_state({ internal = 0, client = 3, action = "toggle" }) end,
    pin            = function() return hl.dsp.window.pin() end,
    layout         = function(a) return hl.dsp.layout(a) end,
    special        = function(a) return hl.dsp.workspace.toggle_special((a ~= "" and a) or "special") end,
    -- group-aware: arg = group index 1..10, resolved to the real workspace per press
    focus_ws_group = function(a) return function() hl.dispatch(hl.dsp.focus({ workspace = workspace_in_group(tonumber(a)) })) end end,
    move_ws_group  = function(a) return function() hl.dispatch(hl.dsp.window.move({ workspace = workspace_in_group(tonumber(a)), follow = false })) end end,
    zoom           = function(a) return function() zoomfunction(tonumber(a) or 0) end end,
}

local FLAGS = { "locked", "repeating", "ignore_mods", "transparent", "release", "mouse", "non_consuming" }

local function apply(data)
    if type(data) ~= "table" or type(data.binds) ~= "table" then return false end
    for _, e in ipairs(data.binds) do
        if type(e) == "table" and type(e.key) == "string" and e.key ~= "" and not e.disabled then
            local build = B[e.action]
            if build then
                pcall(function()
                    local combo = (e.mods and e.mods ~= "") and (e.mods .. " + " .. e.key) or e.key
                    local opts = {}
                    if e.desc and e.desc ~= "" then opts.description = e.desc end
                    if type(e.flags) == "table" then
                        for _, f in ipairs(FLAGS) do if e.flags[f] then opts[f] = true end end
                    end
                    hl.bind(combo, build(e.arg or ""), opts)
                end)
            end
        end
    end
    return true
end

local ok, data = pcall(require, "custom.keybinds")
if ok then apply(data) end

-- Virtual-machine submap: submap definitions aren't flat binds, so this one special
-- feature stays in the engine. SUPER+ALT+F1 toggles a mode that disables all binds.
pcall(function()
    hl.define_submap("virtual-machine", function()
        hl.bind("SUPER + ALT + F1", function()
            local cur = hl.get_current_submap()
            if cur == "virtual-machine" then
                hl.dispatch(hl.dsp.exec_cmd("notify-send 'Exited Virtual Machine submap' 'Keybinds re-enabled' -a 'Hyprland'"))
                hl.dispatch(hl.dsp.submap("reset"))
            elseif cur == "" then
                hl.dispatch(hl.dsp.exec_cmd("notify-send 'Entered Virtual Machine submap' 'Keybinds disabled. hit SUPER+ALT+F1 to escape' -a 'Hyprland'"))
                hl.dispatch(hl.dsp.submap("virtual-machine"))
            end
        end, { submap_universal = true })
    end)
end)
