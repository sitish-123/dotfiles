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

# Escape the replacement for sed (path may contain / and &).
esc=$(printf '%s' "$wall" | sed -e 's/[&/\]/\\&/g')
TAG="# @lock:wallpaper (auto-synced from Settings by scripts/hyprlock/apply-wallpaper.sh)"

if grep -q '@lock:wallpaper' "$HYPRLOCK_CONF"; then
    # Marked line(s) present: rewrite the value, keep the marker.
    sed -i -E "s|^([[:space:]]*path[[:space:]]*=[[:space:]]*).*(#[[:space:]]*@lock:wallpaper.*)$|\1${esc}   \2|" "$HYPRLOCK_CONF"
else
    # Marker was stripped (the Settings lock-wallpaper picker rewrites `path =` without it).
    # Re-tag every path line so auto-sync self-heals. hyprlock.conf only has the
    # background + profile-image path lines, both of which should be the wallpaper.
    sed -i -E "s|^([[:space:]]*path[[:space:]]*=[[:space:]]*).*$|\1${esc}   ${TAG}|" "$HYPRLOCK_CONF"
fi

echo "hyprlock wallpaper -> $wall"
