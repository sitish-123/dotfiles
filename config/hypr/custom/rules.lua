-- kitty transparency is handled by kitty's own `background_opacity` (translucent
-- background, crisp text). A whole-window opacity rule here would dim the text too,
-- so it's intentionally removed. Re-add an `opacity` rule if you want the whole
-- window (text included) translucent instead.

-- AI sidebar: the Gemini/ChatGPT/Claude panel is a native layer-shell app (pkgs/ai-sidebar,
-- bound to SUPER+A). Layer rules give it the old-sidebar feel: slide in/out from the left
-- and blur the translucent panel background (the inset/padding is frosted; web content is
-- opaque). Namespace is "ai-sidebar" (the LayerShellQt scope).
hl.layer_rule({ match = { namespace = "ai-sidebar" }, animation = "slide left" })
hl.layer_rule({ match = { namespace = "ai-sidebar" }, blur = true })
