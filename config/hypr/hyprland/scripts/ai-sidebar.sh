#!/usr/bin/env bash
# AI panel — replaces the old left sidebar. Gemini + ChatGPT + Claude as clean chromium
# --app windows (your normal web login, NO API key), floating + docked to the left edge,
# stacked on the "ai" special workspace. A Quickshell pill bar (modules/ii/aiPanel) sits
# on top and raises the chosen one. SUPER+A toggles the panel; first run launches the three.
set -uo pipefail

URLS=("https://gemini.google.com/app" "https://chatgpt.com/" "https://claude.ai/new")
CLASSES=(Gemini ChatGPT Claude)
BROWSER="$(command -v chromium || command -v chromium-browser || command -v brave || command -v google-chrome-stable || true)"

ai_count() { hyprctl clients -j | jq '[.[] | select(.class=="Gemini" or .class=="ChatGPT" or .class=="Claude")] | length'; }
special_shown() { hyprctl monitors -j | jq -e '.[] | select(.focused) | .specialWorkspace.name=="special:ai"' >/dev/null 2>&1; }

# Already launched -> just toggle visibility (slide in/out).
if [ "$(ai_count)" -ge 1 ]; then
    hyprctl dispatch togglespecialworkspace ai >/dev/null 2>&1
    exit 0
fi

# First run: need a Chromium-based browser for --app mode.
if [ -z "$BROWSER" ]; then
    notify-send -a "AI panel" "AI panel" "No Chromium browser found. Install the optional 'browser' group (chromium)."
    exit 1
fi

# Show the (empty) special workspace so the windows map into view, then launch the three.
special_shown || hyprctl dispatch togglespecialworkspace ai >/dev/null 2>&1
for i in 0 1 2; do
    "$BROWSER" --app="${URLS[$i]}" --class="${CLASSES[$i]}" --name="${CLASSES[$i]}" >/dev/null 2>&1 &
done

# Wait for all three to map (window rule floats + docks them on special:ai), then raise
# Gemini as the default-visible one (they're stacked at the same spot).
for _ in $(seq 1 60); do [ "$(ai_count)" -ge 3 ] && break; sleep 0.2; done
hyprctl dispatch focuswindow "class:^(Gemini)$" >/dev/null 2>&1 || true
