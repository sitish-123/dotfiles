#!/usr/bin/env bash
# Pull the latest dotfiles + fork, rebuild the plugin, re-link, reload.
source "$(dirname "$0")/lib/common.sh"

info "Pulling dotfiles"
git -C "$DOT_ROOT" pull --ff-only || warn "pull skipped (local changes? run sync.sh first)"

info "Updating submodules (hyprtasking fork)"
git -C "$DOT_ROOT" submodule update --init --remote --recursive || warn "submodule update failed"

# Plugin ABI sync. Hyprland plugins are compiled against ONE exact Hyprland version's
# headers. If Hyprland was upgraded since the last run (pacman -Syu / topgrade / a
# re-run of install.sh), both the hyprpm-managed plugins (scrolloverview) and our meson
# fork are ABI-stale and silently fail to load until rebuilt. Detect the version bump
# and refresh headers + reconfigure the fork.
STATE="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/hyprland-version"
CUR_HVER="$(pacman -Q hyprland 2>/dev/null | awk '{print $2}')"
PREV_HVER="$(cat "$STATE" 2>/dev/null || true)"
HVER_CHANGED=0
{ [ -n "$CUR_HVER" ] && [ "$CUR_HVER" != "$PREV_HVER" ]; } && HVER_CHANGED=1 || true

if [ "$HVER_CHANGED" -eq 1 ] && have hyprpm; then
    info "Hyprland changed (${PREV_HVER:-none} -> $CUR_HVER) — refreshing hyprpm headers/plugins"
    hyprpm update || warn "hyprpm update reported issues"
fi

info "Rebuilding hyprtasking"
FORK="$DOT_ROOT/pkgs/hyprtasking"
if [ -d "$FORK/build" ]; then
    # On a Hyprland bump the cached meson config still points at the old headers — reconfigure.
    [ "$HVER_CHANGED" -eq 1 ] && meson setup --reconfigure "$FORK/build" "$FORK" >/dev/null 2>&1 || true
    if meson compile -C "$FORK/build" 2>/dev/null; then ok "fork rebuilt"; else warn "fork rebuild skipped"; fi
else
    warn "fork build dir missing — run install.sh first"
fi

# Re-ensure config symlinks (no-op if already linked).
for d in "${MANAGED_CONFIGS[@]}"; do
    if [ -d "$DOT_ROOT/config/$d" ] && [ ! -L "$CONFIG_HOME/$d" ]; then
        link "$DOT_ROOT/config/$d" "$CONFIG_HOME/$d"
    fi
done

# Record the Hyprland version we just built against, so the next run detects the next bump.
[ -n "$CUR_HVER" ] && { mkdir -p "$(dirname "$STATE")"; printf '%s\n' "$CUR_HVER" > "$STATE"; }

have hyprpm  && hyprpm reload  >/dev/null 2>&1 || true
have hyprctl && hyprctl reload >/dev/null 2>&1 || true
ok "Update complete."
