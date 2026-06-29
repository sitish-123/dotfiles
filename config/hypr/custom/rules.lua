-- kitty transparency is handled by kitty's own `background_opacity` (translucent
-- background, crisp text). A whole-window opacity rule here would dim the text too,
-- so it's intentionally removed. Re-add an `opacity` rule if you want the whole
-- window (text included) translucent instead.

-- AI panel (replaces the left sidebar): Gemini/ChatGPT/Claude chromium --app windows
-- live on the "ai" special workspace, where ai-sidebar.sh groups them into a tab group.
-- SUPER+A toggles the workspace. Kept tiled (not floating) so Hyprland can tab them.
hl.window_rule({ match = { class = "^(Gemini|ChatGPT|Claude)$" }, workspace = "special:ai" })
