#!/usr/bin/env bash
# Sync hypridle's timeouts from the quickshell config, then (re)start hypridle.
# Source of truth: ~/.config/illogical-impulse/config.json (.idle.*). This only rewrites
# the marked `timeout = N # @idle:<name>` numbers, so it can't corrupt hypridle.conf.
# Run at login (from execs.lua) and whenever Settings > Power changes an idle value.
set -u
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/illogical-impulse/config.json"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hypridle.conf"
[ -f "$CONF" ] || exit 0

# Read minutes with safe fallbacks; clamp to >= 1 so a bad value can't lock instantly.
getmin() {
    local v=""
    [ -f "$CFG" ] && v=$(jq -r ".idle.$1 // empty" "$CFG" 2>/dev/null)
    if [[ "$v" =~ ^[0-9]+$ ]] && [ "$v" -ge 1 ]; then echo "$v"; else echo "$2"; fi
}
lock_s=$(( $(getmin lockMinutes 5) * 60 ))
off_s=$(( $(getmin screenOffMinutes 10) * 60 ))
susp_s=$(( $(getmin suspendMinutes 15) * 60 ))
# NB: jq's `//` treats false as empty, so read the bool directly; only "false" disables.
[ "$(jq -r '.idle.autoSuspend' "$CFG" 2>/dev/null)" = "false" ] && susp_s=86400  # ~never

set_timeout() { # <seconds> <marker>
    sed -i -E "s/^([[:space:]]*timeout = )[0-9]+([[:space:]]*#[[:space:]]*@idle:$2\b)/\1$1\2/" "$CONF"
}
set_timeout "$lock_s"  lock
set_timeout "$off_s"   screenoff
set_timeout "$susp_s"  suspend

# Restart hypridle so the new config takes effect (it doesn't hot-reload).
pkill -x hypridle 2>/dev/null
sleep 0.2
setsid hypridle >/dev/null 2>&1 </dev/null &
