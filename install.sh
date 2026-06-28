#!/usr/bin/env bash
# Fresh-machine setup: packages -> submodule -> plugins/fork -> symlink configs.
# Idempotent: safe to re-run. Existing real configs are backed up before linking.
source "$(dirname "$0")/lib/common.sh"

info "dotfiles install — root: $DOT_ROOT"

# 1) Packages (Arch). Best-effort; skip if not on pacman.
PKGFILE="$DOT_ROOT/bootstrap/packages.txt"
if have pacman; then
    mapfile -t OFFICIAL < <(grep -vE '^\s*#|^\s*$|^aur:' "$PKGFILE")
    mapfile -t AUR < <(grep '^aur:' "$PKGFILE" | sed 's/^aur://')
    info "Installing ${#OFFICIAL[@]} official packages"
    sudo pacman -S --needed --noconfirm "${OFFICIAL[@]}" || warn "some official packages failed"
    if have yay; then
        info "Installing ${#AUR[@]} AUR packages"
        yay -S --needed --noconfirm "${AUR[@]}" || warn "some AUR packages failed"
    elif [ "${#AUR[@]}" -gt 0 ]; then
        warn "No AUR helper found — install manually: yay -S ${AUR[*]}"
    fi
    # ydotool daemon (virtual keyboard: clipboard paste, on-screen keyboard)
    have ydotoold && systemctl --user enable --now ydotool 2>/dev/null || \
        warn "couldn't enable ydotool daemon (needed for paste/OSK) — check uinput perms"
else
    warn "Not an Arch system — install packages from $PKGFILE manually"
fi

# 2) Submodules (the hyprtasking fork).
info "Fetching submodules"
git -C "$DOT_ROOT" submodule update --init --recursive || warn "submodule init failed"

# 3) Symlink managed configs into ~/.config (backs up anything existing).
info "Linking configs into $CONFIG_HOME"
for d in "${MANAGED_CONFIGS[@]}"; do
    [ -d "$DOT_ROOT/config/$d" ] && link "$DOT_ROOT/config/$d" "$CONFIG_HOME/$d"
done

# 4) Plugins + fork build.
bash "$DOT_ROOT/bootstrap/plugins.sh" || warn "plugin setup had issues"

ok "Install complete. Log into Hyprland (or reload) to apply."
info "Reflect future edits to GitHub with:  $DOT_ROOT/sync.sh"
