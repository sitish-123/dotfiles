#!/usr/bin/env bash
# Fresh-machine setup: packages -> submodule -> plugins/fork -> symlink configs.
# Idempotent: safe to re-run. Existing real configs are backed up before linking.
source "$(dirname "$0")/lib/common.sh"

info "dotfiles install — root: $DOT_ROOT"

# 1) Packages (Arch). Best-effort; skip if not on pacman.
if have pacman; then
    info "Installing packages (sudo pacman)"
    sudo pacman -S --needed --noconfirm - < "$DOT_ROOT/bootstrap/packages.txt" \
        | grep -v 'is up to date' || warn "some packages skipped (AUR ones need yay)"
    warn "AUR packages (quickshell-git, matugen-bin) — install with: yay -S quickshell-git matugen-bin"
else
    warn "Not an Arch system — install packages from bootstrap/packages.txt manually"
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
