#!/usr/bin/env bash
# Set up Hyprland plugins: hyprpm headers, the scrolloverview alt overview, and
# build our hyprtasking fork (the pkgs/hyprtasking submodule).
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

have hyprpm || die "hyprpm not found (install hyprland)"

info "Updating hyprpm headers"
hyprpm update || warn "hyprpm update reported issues (continuing)"

# Optional niri-style carousel overview (community plugin).
if ! hyprpm list 2>/dev/null | grep -qi scrolloverview; then
    info "Adding scrolloverview"
    hyprpm add https://github.com/yayuuu/hyprland-scroll-overview.git || warn "scrolloverview add failed"
fi

# Build our hyprtasking fork (adaptive grid + the rest).
FORK="$DOT_ROOT/pkgs/hyprtasking"
if [ -d "$FORK" ]; then
    info "Building hyprtasking fork"
    meson setup "$FORK/build" "$FORK" >/dev/null 2>&1 || true
    meson compile -C "$FORK/build" && ok "hyprtasking built" || warn "hyprtasking build failed"
    # The overview switcher expects the build at ~/Projects/hyprtasking/build.
    # Symlink the submodule there so one canonical path works everywhere.
    [ -e "$HOME/Projects/hyprtasking" ] || ln -s "$FORK" "$HOME/Projects/hyprtasking"
fi

hyprpm reload >/dev/null 2>&1 || true
ok "plugins ready"
