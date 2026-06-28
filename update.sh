#!/usr/bin/env bash
# Pull the latest dotfiles + fork, rebuild the plugin, re-link, reload.
source "$(dirname "$0")/lib/common.sh"

info "Pulling dotfiles"
git -C "$DOT_ROOT" pull --ff-only || warn "pull skipped (local changes? run sync.sh first)"

info "Updating submodules (hyprtasking fork)"
git -C "$DOT_ROOT" submodule update --init --remote --recursive || warn "submodule update failed"

info "Rebuilding hyprtasking"
FORK="$DOT_ROOT/pkgs/hyprtasking"
[ -d "$FORK" ] && meson compile -C "$FORK/build" 2>/dev/null && ok "fork rebuilt" || warn "fork rebuild skipped"

# Re-ensure config symlinks (no-op if already linked).
for d in "${MANAGED_CONFIGS[@]}"; do
    if [ -d "$DOT_ROOT/config/$d" ] && [ ! -L "$CONFIG_HOME/$d" ]; then
        link "$DOT_ROOT/config/$d" "$CONFIG_HOME/$d"
    fi
done

have hyprctl && hyprctl reload >/dev/null 2>&1 || true
ok "Update complete."
