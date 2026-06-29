#!/usr/bin/env bash
# Build our hyprtasking fork (the pkgs/hyprtasking submodule) — the one overview
# plugin this setup uses. It compiles against the SYSTEM Hyprland headers (the
# hyprland.pc pulled in by the hyprland package), so there's no hyprpm step and no
# header-cache to keep in sync.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

# The fork build needs this toolchain (meson pulls ninja). If the package phase failed
# (e.g. a stale-DB 404 storm took out meson), bail early with one clear line instead of
# a confusing cascade ("meson: command not found" / "Package hyprland was not found").
MISSING=()
for t in meson g++ pkg-config; do have "$t" || MISSING+=("$t"); done
pkg-config --exists hyprland 2>/dev/null || MISSING+=("hyprland(-devel headers)")
if [ "${#MISSING[@]}" -gt 0 ]; then
    warn "plugin toolchain missing: ${MISSING[*]} — fix packages first (sudo pacman -Syu), then re-run install.sh"
    exit 0
fi

# The vendored hypr config is authored against current Hyprland. A much OLDER Hyprland
# will choke on config keywords that didn't exist yet / were renamed. Warn loudly so a
# machine stuck on an old version (e.g. behind mirrors) gets a clear pointer.
HYPR_MIN="0.55.0"   # bump when the config starts relying on newer syntax
HVER="$(pacman -Q hyprland 2>/dev/null | awk '{print $2}' | cut -d- -f1)"
if [ -n "$HVER" ] && [ "$(printf '%s\n%s\n' "$HYPR_MIN" "$HVER" | sort -V | head -1)" != "$HYPR_MIN" ]; then
    warn "Hyprland $HVER is older than $HYPR_MIN — the config may fail to parse. Run: sudo pacman -Syu"
fi

# Build our hyprtasking fork (adaptive grid + the rest). This is the only overview
# plugin — loaded at login via custom/scripts/overview-switch.sh (hyprctl plugin load).
FORK="$DOT_ROOT/pkgs/hyprtasking"
if [ -d "$FORK" ]; then
    info "Building hyprtasking fork"
    meson setup "$FORK/build" "$FORK" >/dev/null 2>&1 || true
    meson compile -C "$FORK/build" && ok "hyprtasking built" || warn "hyprtasking build failed"
    # The overview switcher expects the build at ~/Projects/hyprtasking/build.
    # Symlink the submodule there so one canonical path works everywhere.
    [ -e "$HOME/Projects/hyprtasking" ] || ln -s "$FORK" "$HOME/Projects/hyprtasking"
fi

ok "plugins ready"
