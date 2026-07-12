#!/usr/bin/env bash
# Overview control for Hyprland. We use ONE overview plugin: our hyprtasking fork.
# hyprland/hyprtasking.lua reads the state file + applies the fork config; the 4-finger
# gesture is handled inside the plugin itself (not general.lua).
#
#   overview-switch.sh hyprtasking   # load the fork overview (default)
#   overview-switch.sh off           # no overview plugin
#   overview-switch.sh toggle        # open/close the active overview
#   overview-switch.sh restore       # run once at login to reload the last state
#
# We load/unload the .so path directly with `hyprctl plugin` (no hyprpm).
set -uo pipefail

STATE="$HOME/.config/hypr/custom/overview.state"
FORK_SO="$HOME/Projects/hyprtasking/build/libhyprtasking.so"

# Legacy .so paths from the old multi-plugin setup (scrolloverview / stock hyprtasking).
# We never load these anymore, but unload them defensively so a machine migrating off
# the old switcher drops them cleanly on the next switch/login.
_LEGACY_SO=(
  "/var/cache/hyprpm/$USER/hyprland-scroll-overview/scrolloverview.so"
  "/var/cache/hyprpm/$USER/hyprtasking/hyprtasking.so"
)

notify() { command -v notify-send >/dev/null 2>&1 && notify-send -t 2000 "$1" "$2" 2>/dev/null || true; }

# `hyprctl reload` re-applies the monitor config, which resets the monitor's active
# workspace (jumps you to another workspace). Save the current workspace and restore
# it after the reload so config changes don't yank you away.
reload_keep_ws() {
    local ws
    ws="$(hyprctl activeworkspace 2>/dev/null | grep -oE 'ID -?[0-9]+' | awk '{print $2}' | head -1)"
    hyprctl reload >/dev/null 2>&1
    # Restore via `hyprctl eval hl.dispatch(...)` — this is a Lua-config Hyprland, where
    # `hyprctl dispatch workspace N` is (mis)parsed as Lua and errors. Only restore normal
    # (positive) workspaces; skip special/scratchpad. Short settle so the reset lands first.
    if [ -n "$ws" ] && [ "$ws" -gt 0 ] 2>/dev/null; then
        sleep 0.4
        hyprctl eval "hl.dispatch(hl.dsp.focus({workspace = $ws}))" >/dev/null 2>&1
    fi
}

unload_all() {
  for so in "$FORK_SO" "${_LEGACY_SO[@]}"; do
    hyprctl plugin unload "$so" >/dev/null 2>&1 || true
  done
}

case "${1:-}" in
  hyprtasking|tasking|grid|fork|dev|on)
      if [ ! -f "$FORK_SO" ]; then notify "Overview" "Fork not built — run ~/Projects/hyprtasking/dev.sh build"; exit 1; fi
      echo hyprtasking > "$STATE"
      # All fork settings (adaptive/blur_bg/rounding/...) live in hyprland/hyprtasking.lua
      # and apply on the reload below. Unload only the LEGACY plugins — NOT the fork:
      # unloading the fork while it's loaded (possibly mid-frame / overview open) is the
      # documented crash race that the 'restore' path is written to avoid. Load the fork
      # only if it isn't already loaded (an in-place reload can't reliably hot-swap a new
      # build anyway — that needs a relog).
      for so in "${_LEGACY_SO[@]}"; do hyprctl plugin unload "$so" >/dev/null 2>&1 || true; done
      if ! hyprctl plugin list 2>/dev/null | grep -qi hyprtasking; then
          hyprctl plugin load "$FORK_SO" >/dev/null 2>&1
      fi
      reload_keep_ws
      notify "Overview" "hyprtasking (adaptive grid)"
      ;;

  off|none|disable)
      echo none > "$STATE"
      unload_all
      reload_keep_ws
      notify "Overview" "disabled"
      ;;

  toggle)
      cur="$(cat "$STATE" 2>/dev/null || echo hyprtasking)"
      [ "$cur" = none ] && exit 0
      # hyprctl eval runs Lua directly; dispatch wraps in hl.dispatch() which errors for
      # helpers that don't return a dispatcher (hyprtasking.toggle is one).
      hyprctl eval 'hl.plugin.hyprtasking.toggle("cursor")' >/dev/null 2>&1
      ;;

  restore|startup)
      # Run ONCE at login (from custom/execs.lua) to load the last-active overview, so it
      # never needs manual re-enabling each boot. Single load with nothing else loaded yet
      # -> no unload, avoiding the plugin-reload race that crashes Hyprland mid-frame. The
      # settle delay lets the compositor come up; the reload re-runs custom/general.lua,
      # which applies the fork's config now that the plugin is loaded.
      sleep 1.5
      cur="$(cat "$STATE" 2>/dev/null || echo hyprtasking)"
      [ "$cur" = none ] && exit 0
      [ -f "$FORK_SO" ] && hyprctl plugin load "$FORK_SO" >/dev/null 2>&1
      reload_keep_ws
      ;;

  *) echo "usage: overview-switch.sh <hyprtasking|off|toggle|restore>"; exit 1 ;;
esac
true
