#!/usr/bin/env bash
# Sync hyprlock's wallpaper with the Settings value, so hyprlock and the
# quickshell lock use one source of truth.
#
#   Settings (config.json):
#     background.wallpaperPathLock  -> lock-screen wallpaper (empty = same as desktop)
#     background.wallpaperPath      -> desktop wallpaper (fallback)
#
# It rewrites every line in hyprlock.conf tagged with `# @lock:wallpaper`.
# Run it: on wallpaper change (hooked from switchwall.sh) or manually anytime.
set -euo pipefail

CONFIG_JSON="${XDG_CONFIG_HOME:-$HOME/.config}/illogical-impulse/config.json"
HYPRLOCK_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprlock.conf"

[ -f "$CONFIG_JSON" ]  || { echo "no config.json"; exit 1; }
[ -f "$HYPRLOCK_CONF" ] || { echo "no hyprlock.conf"; exit 1; }

lock=$(jq -r '.background.wallpaperPathLock // ""' "$CONFIG_JSON")
desktop=$(jq -r '.background.wallpaperPath // ""' "$CONFIG_JSON")
wall="${lock:-$desktop}"

# Expand a leading ~ (hyprlock does not always expand it)
case "$wall" in "~/"*) wall="$HOME/${wall#\~/}";; esac

[ -n "$wall" ] || { echo "no wallpaper set"; exit 0; }
[ -f "$wall" ] || echo "warning: wallpaper '$wall' does not exist (writing anyway)"

# Rewrite the path on every line marked with the tag, preserving indentation + tag.
# Escape the replacement for sed (path may contain / and &).
esc=$(printf '%s' "$wall" | sed -e 's/[&/\]/\\&/g')
sed -i -E "s|^([[:space:]]*path[[:space:]]*=[[:space:]]*).*(# @lock:wallpaper.*)$|\1${esc}   \2|" "$HYPRLOCK_CONF"

echo "hyprlock wallpaper -> $wall"
