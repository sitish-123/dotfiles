-- ═══════════════════════════════════════════════════════════════════════════
-- User autostart (exec-once) — APPLY LOGIC (tracked; don't edit for settings)
-- ═══════════════════════════════════════════════════════════════════════════
-- GUI-managed startup commands, same data/logic split as wm.lua. The DATA lives
-- in custom/autostart.lua (user/GUI-owned, seeded from custom.defaults/autostart.lua);
-- this file reads it and runs each enabled command once on Hyprland start. It is
-- SEPARATE from custom/execs.lua (which holds critical hand-managed session bringup)
-- so the GUI never clobbers that.
--   • Edit from the GUI: Settings > Autostart (writes custom/autostart.lua).
--   • Or edit custom/autostart.lua directly. Format:
--       return { commands = { { cmd = "...", enabled = true }, ... } }
-- pcall-guarded so a malformed data file can never trip emergency mode.
-- ═══════════════════════════════════════════════════════════════════════════

local ok, user = pcall(require, "custom.autostart")
if ok and type(user) == "table" and type(user.commands) == "table" then
    hl.on("hyprland.start", function()
        for _, c in ipairs(user.commands) do
            if type(c) == "table" and type(c.cmd) == "string" and c.cmd ~= "" and c.enabled ~= false then
                pcall(function() hl.exec_cmd(c.cmd) end)
            end
        end
    end)
end
