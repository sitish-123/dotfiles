#!/usr/bin/env bash
# Self-built AI "desktop apps" — no third-party packages, no Electron, no trust issues.
#   Gemini / ChatGPT : chromium PWAs (--app). They use YOUR chromium profile, so you're
#                      already logged in, Google's webview-login block doesn't apply, and
#                      they always run the live site. A real standalone window (own class,
#                      own launcher entry, no browser chrome).
#   Claude Code      : opens the `claude` CLI in a terminal (it's terminal-only on Linux).
# Idempotent: re-run any time. Generates .desktop files with absolute paths for THIS
# machine, so it's correct regardless of $HOME / username.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPS_DIR="$HOME/.local/share/applications"
ICONS_DIR="$HOME/.local/share/icons/ii-webapps"
mkdir -p "$APPS_DIR" "$ICONS_DIR"
cp -f "$SCRIPT_DIR"/*.svg "$ICONS_DIR"/ 2>/dev/null || true

# Pick a Chromium-based browser (PWA --app mode needs one). Brave/Chrome/Edge also work.
BROWSER=""
for b in chromium chromium-browser brave brave-browser google-chrome-stable microsoft-edge-stable vivaldi-stable; do
    command -v "$b" >/dev/null 2>&1 && { BROWSER="$b"; break; }
done

# Terminal for the Claude Code launcher (matches the desktop default: kitty).
TERM_BIN="$(command -v kitty || command -v foot || command -v alacritty || echo xterm)"

write_pwa() { # <Name> <url> <Class> <icon-file>
    local name="$1" url="$2" cls="$3" icon="$4"
    if [ -z "$BROWSER" ]; then return 1; fi
    cat > "$APPS_DIR/$name.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$name
GenericName=AI assistant
Comment=$name (web app)
Exec=$BROWSER --app=$url --class=$cls --name=$cls
Icon=$ICONS_DIR/$icon
StartupWMClass=$cls
Categories=Network;Chat;Utility;
Terminal=false
EOF
    echo "  + $name.desktop"
}

if [ -n "$BROWSER" ]; then
    echo ":: Web apps via $BROWSER"
    write_pwa "Gemini"  "https://gemini.google.com/app" "Gemini"  "gemini.svg"
    write_pwa "ChatGPT" "https://chatgpt.com/"          "ChatGPT" "chatgpt.svg"
    write_pwa "Claude"  "https://claude.ai/new"         "Claude"  "claude.svg"
else
    echo "!! No Chromium-based browser found — skipping Gemini/ChatGPT web apps."
    echo "   Install one (e.g. the optional 'browser' group: chromium), then re-run this."
fi

# Claude Code — run the CLI in a terminal; login shell so its PATH (npm/global) is loaded.
cat > "$APPS_DIR/Claude Code.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Claude Code
GenericName=AI coding agent
Comment=Claude Code CLI in a terminal
Exec=$TERM_BIN bash -lc 'command -v claude >/dev/null && exec claude || { echo "Claude Code not installed. Install with: npm i -g @anthropic-ai/claude-code"; exec bash; }'
Icon=$ICONS_DIR/claude.svg
Categories=Development;Utility;
Terminal=false
EOF
echo "  + Claude Code.desktop"

update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
echo ":: AI app launchers ready (search 'Gemini' / 'ChatGPT' / 'Claude Code' in the launcher)"
