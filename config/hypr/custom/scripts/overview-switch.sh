#!/usr/bin/env bash
# Overview control for Hyprland. We use ONE overview plugin: our hyprtasking fork.
# custom/general.lua reads the state file and wires the 4-finger-up gesture.
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

unload_all() {
  for so in "$FORK_SO" "${_LEGACY_SO[@]}"; do
    hyprctl plugin unload "$so" >/dev/null 2>&1 || true
  done
}

case "${1:-}" in
  hyprtasking|tasking|grid|fork|dev|on)
      if [ ! -f "$FORK_SO" ]; then notify "Overview" "Fork not built — run ~/Projects/hyprtasking/dev.sh build"; exit 1; fi
      echo hyprtasking > "$STATE"
      # All fork settings (adaptive/blur_bg/rounding/...) live in custom/general.lua and
      # apply on the reload below — no runtime eval, so they survive reloads and every
      # trigger opens the same configured overview.
      unload_all; sleep 0.3
      hyprctl plugin load "$FORK_SO" >/dev/null 2>&1
      hyprctl reload >/dev/null 2>&1
      notify "Overview" "hyprtasking (adaptive grid)"
      ;;

  off|none|disable)
      echo none > "$STATE"
      unload_all
      hyprctl reload >/dev/null 2>&1
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
      hyprctl reload >/dev/null 2>&1
      ;;

  *) echo "usage: overview-switch.sh <hyprtasking|off|toggle|restore>"; exit 1 ;;
esac
true
