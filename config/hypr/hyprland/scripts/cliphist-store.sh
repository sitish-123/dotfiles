#!/usr/bin/env bash
# Stores the new clipboard entry (stdin, from `wl-paste --watch`) AND records a
# timestamp for it so the quickshell clipboard view can show times / group by day.
# cliphist itself stores no timestamps, hence this sidecar.
cliphist store

TSV="$HOME/.local/state/quickshell/user/cliphist_times.tsv"   # lines: "<id> <epoch>"
mkdir -p "$(dirname "$TSV")"

# The just-stored entry is cliphist's newest (top of the list).
id="$(cliphist list 2>/dev/null | head -1 | cut -f1)"
if [ -n "$id" ]; then
    printf '%s %s\n' "$id" "$(date +%s)" >> "$TSV"
    # keep the sidecar bounded
    tail -n 1000 "$TSV" > "$TSV.tmp" 2>/dev/null && mv "$TSV.tmp" "$TSV"
fi

qs -c ii ipc call cliphistService update 2>/dev/null || true
