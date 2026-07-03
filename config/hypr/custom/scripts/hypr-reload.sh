#!/usr/bin/env bash
# Jump-free `hyprctl reload`. Hyprland re-applies monitors on reload, which resets the
# active workspace to 1 — this saves the current workspace and restores it after.
# NOTE: this is a Lua-config Hyprland, so `hyprctl dispatch workspace N` errors (parsed
# as Lua); the restore goes through `hyprctl eval hl.dispatch(...)`. Bind this or call it
# instead of a bare `hyprctl reload`.
ws="$(hyprctl activeworkspace 2>/dev/null | grep -oE 'ID -?[0-9]+' | awk '{print $2}' | head -1)"
hyprctl reload
if [ -n "$ws" ] && [ "$ws" -gt 0 ] 2>/dev/null; then
    sleep 0.4
    hyprctl eval "hl.dispatch(hl.dsp.focus({workspace = $ws}))" >/dev/null 2>&1
fi
