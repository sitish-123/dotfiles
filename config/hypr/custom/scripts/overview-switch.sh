#!/usr/bin/env bash
# Overview switcher for Hyprland. Exactly ONE overview plugin loaded at a time;
# custom/general.lua reads the state file and wires the 4-finger-up gesture.
#
#   overview-switch.sh scrolloverview   # niri-style scrollable carousel
#   overview-switch.sh hyprtasking      # stock hyprtasking (stable, fixed grid)
#   overview-switch.sh fork             # OUR fork build (adaptive grid ON, dev/test)
#   overview-switch.sh off              # no overview plugin
#   overview-switch.sh toggle           # open/close the active one
#
# Two overview plugins loaded at once => "failed enabling overview hooks", so we
# always unload everything first, then load exactly one. `hyprpm reload` does NOT
# reliably unload, so we load/unload .so paths directly.
set -uo pipefail

STATE="$HOME/.config/hypr/custom/overview.state"
CACHE="/var/cache/hyprpm/$USER"
SCROLL_SO="$CACHE/hyprland-scroll-overview/scrolloverview.so"
STOCK_SO="$CACHE/hyprtasking/hyprtasking.so"
FORK_SO="$HOME/Projects/hyprtasking/build/libhyprtasking.so"

notify() { command -v notify-send >/dev/null 2>&1 && notify-send -t 2000 "$1" "$2" 2>/dev/null || true; }

unload_all() {
  for so in "$SCROLL_SO" "$STOCK_SO" "$FORK_SO"; do
    hyprctl plugin unload "$so" >/dev/null 2>&1 || true
  done
}

case "${1:-}" in
  scrolloverview|niri|scroll)
      echo scrolloverview > "$STATE"
      hyprpm disable hyprtasking >/dev/null 2>&1; hyprpm enable scrolloverview >/dev/null 2>&1
      unload_all; sleep 0.3
      hyprctl plugin load "$SCROLL_SO" >/dev/null 2>&1
      hyprctl reload >/dev/null 2>&1
      notify "Overview" "scrolloverview (niri carousel)"
      ;;

  hyprtasking|tasking|grid|fork|dev|hyprtasking-fork)
      if [ ! -f "$FORK_SO" ]; then notify "Overview" "Fork not built — run ~/Projects/hyprtasking/dev.sh build"; exit 1; fi
      echo hyprtasking > "$STATE"
      # The fork IS our hyprtasking. Keep stock hyprpm hyprtasking disabled so it
      # never loads (its missing fork keys would error against our config). All
      # fork settings (adaptive/blur_bg/rounding/...) live in custom/general.lua
      # and apply on the reload below — no runtime eval, so they survive reloads
      # and every trigger opens the same configured overview.
      hyprpm disable hyprtasking >/dev/null 2>&1; hyprpm disable scrolloverview >/dev/null 2>&1
      unload_all; sleep 0.3
      hyprctl plugin load "$FORK_SO" >/dev/null 2>&1
      hyprctl reload >/dev/null 2>&1
      notify "Overview" "hyprtasking (adaptive grid)"
      ;;

  off|none|disable)
      echo none > "$STATE"
      hyprpm disable hyprtasking >/dev/null 2>&1; hyprpm disable scrolloverview >/dev/null 2>&1
      unload_all
      hyprctl reload >/dev/null 2>&1
      notify "Overview" "disabled"
      ;;

  toggle)
      cur="$(cat "$STATE" 2>/dev/null || echo scrolloverview)"
      # hyprctl eval runs Lua directly; dispatch wraps in hl.dispatch() which
      # errors for helpers that don't return a dispatcher (e.g. hyprtasking.toggle).
      case "$cur" in
        scrolloverview) hyprctl eval 'hl.plugin.scrolloverview.overview("toggle")' ;;
        hyprtasking)    hyprctl eval 'hl.plugin.hyprtasking.toggle("cursor")' ;;
      esac
      ;;

  restore|startup)
      # Run ONCE at login (from custom/execs.lua) to load whatever overview was last
      # active, so it never needs manual re-enabling each boot. Single load with nothing
      # else loaded yet -> no unload, so it avoids the plugin-reload race that crashes
      # Hyprland when frames render mid-swap. Small settle delay lets the compositor come
      # up first. The hyprctl reload re-runs custom/general.lua, which applies the fork's
      # config (adaptive/blur_bg/rounding/...) now that the plugin is loaded.
      sleep 1.5
      cur="$(cat "$STATE" 2>/dev/null || echo hyprtasking)"
      case "$cur" in
        scrolloverview)
            hyprpm disable hyprtasking >/dev/null 2>&1
            hyprctl plugin load "$SCROLL_SO" >/dev/null 2>&1 ;;
        hyprtasking|fork)
            hyprpm disable hyprtasking >/dev/null 2>&1  # stock stays off; our fork .so IS hyprtasking
            [ -f "$FORK_SO" ] && hyprctl plugin load "$FORK_SO" >/dev/null 2>&1 ;;
        *) exit 0 ;;  # off/none -> load nothing
      esac
      hyprctl reload >/dev/null 2>&1
      ;;

  *) echo "usage: overview-switch.sh <scrolloverview|hyprtasking|fork|off|toggle|restore>"; exit 1 ;;
esac
true
