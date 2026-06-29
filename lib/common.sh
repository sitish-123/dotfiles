#!/usr/bin/env bash
# Shared helpers for the dotfiles scripts.
set -euo pipefail

DOT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

info() { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

# link <repo-path> <target-path> : symlink target -> repo-path, backing up anything real.
link() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    if [ -L "$dst" ]; then
        rm "$dst"
    elif [ -e "$dst" ]; then
        mv "$dst" "$dst.bak.$(date +%Y%m%d%H%M%S)"
        warn "backed up existing $dst -> $dst.bak.*"
    fi
    ln -s "$src" "$dst"
    ok "linked $(basename "$dst") -> $src"
}

have() { command -v "$1" >/dev/null 2>&1; }

# Configs this repo manages, under config/ and symlinked into ~/.config/
MANAGED_CONFIGS=(hypr quickshell matugen illogical-impulse kitty)
