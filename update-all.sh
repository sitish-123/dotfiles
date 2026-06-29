#!/usr/bin/env bash
# One-shot "update everything": system packages (official + AUR) THEN the dotfiles
# (git pull + submodule + ABI-safe plugin rebuild + relink + reload, via update.sh).
# Meant to be run interactively from a terminal — it will prompt for sudo.
source "$(dirname "$0")/lib/common.sh"

# 1) Packages. yay -Syu covers official repos too, so prefer it when present.
if have yay; then
    info "Updating system + AUR packages (yay -Syu)"
    yay -Syu || warn "package update had issues"
elif have pacman; then
    info "Updating system packages (pacman -Syu)"
    sudo pacman -Syu || warn "package update had issues"
else
    warn "No pacman/yay — skipping package update"
fi

# 2) Dotfiles + plugins (pull latest, rebuild fork against current Hyprland, relink, reload).
info "Updating dotfiles + plugins"
bash "$DOT_ROOT/update.sh" || warn "dotfiles update had issues"

ok "Everything up to date."
