-- kitty transparency is handled by kitty's own `background_opacity` (translucent
-- background, crisp text). A whole-window opacity rule here would dim the text too,
-- so it's intentionally removed. Re-add an `opacity` rule if you want the whole
-- window (text included) translucent instead.

-- AI panel (replaces the left sidebar): Gemini/ChatGPT/Claude chromium --app windows
-- FLOAT, docked to the left edge, stacked at the same spot on the "ai" special workspace.
-- A Quickshell pill bar (modules/ii/aiPanel) sits in the top strip (~52px) and raises the
-- chosen one. SUPER+A toggles the workspace (shows the panel + pills together).
local ai_match = { class = "^(Gemini|ChatGPT|Claude)$" }
hl.window_rule({ match = ai_match, workspace = "special:ai" })
hl.window_rule({ match = ai_match, float = true })
hl.window_rule({ match = ai_match, size = {"(monitor_w*0.32)", "(monitor_h-72)"} })
hl.window_rule({ match = ai_match, move = {12, 64} })
