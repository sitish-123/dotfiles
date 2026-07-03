-- ═══════════════════════════════════════════════════════════════════════════
-- User environment variables — APPLY LOGIC (tracked; don't edit for settings)
-- ═══════════════════════════════════════════════════════════════════════════
-- GUI-managed extra environment variables, same data/logic split as wm.lua.
-- The DATA lives in custom/env.lua (user/GUI-owned, seeded from custom.defaults/
-- env.lua); this file reads it and applies each with hl.env. Sourced AFTER
-- hyprland/env.lua so user vars win over the shipped ones.
--   • Edit from the GUI: Settings > Environment (writes custom/env.lua).
--   • Or edit custom/env.lua directly. Format: return { vars = { { name=, value= }, ... } }
-- pcall-guarded end to end so a malformed data file can never trip emergency mode.
-- ═══════════════════════════════════════════════════════════════════════════

local ok, user = pcall(require, "custom.env")
if ok and type(user) == "table" and type(user.vars) == "table" then
    for _, v in ipairs(user.vars) do
        if type(v) == "table" and type(v.name) == "string" and v.name ~= "" then
            pcall(function() hl.env(v.name, tostring(v.value or "")) end)
        end
    end
end
