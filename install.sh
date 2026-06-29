#!/usr/bin/env bash
# Fresh-machine setup: packages -> submodule -> plugins/fork -> symlink configs.
# Idempotent: safe to re-run. Existing real configs are backed up before linking.
source "$(dirname "$0")/lib/common.sh"

# Flags (order-independent): --no-system skips /etc tweaks; --dev also installs the
# opt-in development stack from bootstrap/dev-packages.txt.
WANT_SYSTEM=1; WANT_DEV=0
for a in "$@"; do
    case "$a" in
        --no-system) WANT_SYSTEM=0 ;;
        --dev)       WANT_DEV=1 ;;
    esac
done

info "dotfiles install — root: $DOT_ROOT"

# 1) Packages (Arch). Best-effort; skip if not on pacman.
install_pkgs() { # <packages-file> <label>
    local file="$1" label="$2"
    [ -f "$file" ] || { warn "missing $file"; return; }
    mapfile -t OFFICIAL < <(grep -vE '^\s*#|^\s*$|^aur:' "$file")
    mapfile -t AUR < <(grep '^aur:' "$file" | sed 's/^aur://')
    info "Installing ${#OFFICIAL[@]} official $label packages"
    [ "${#OFFICIAL[@]}" -gt 0 ] && { sudo pacman -S --needed --noconfirm "${OFFICIAL[@]}" || warn "some $label packages failed"; }
    if have yay; then
        info "Installing ${#AUR[@]} AUR $label packages"
        [ "${#AUR[@]}" -gt 0 ] && { yay -S --needed --noconfirm "${AUR[@]}" || warn "some AUR $label packages failed"; }
    elif [ "${#AUR[@]}" -gt 0 ]; then
        warn "No AUR helper found — install manually: yay -S ${AUR[*]}"
    fi
}
if have pacman; then
    install_pkgs "$DOT_ROOT/bootstrap/packages.txt" "base"
    [ "$WANT_DEV" -eq 1 ] && install_pkgs "$DOT_ROOT/bootstrap/dev-packages.txt" "dev"
    # ydotool daemon (virtual keyboard: clipboard paste, on-screen keyboard)
    have ydotoold && systemctl --user enable --now ydotool 2>/dev/null || \
        warn "couldn't enable ydotool daemon (needed for paste/OSK) — check uinput perms"
else
    warn "Not an Arch system — install packages from bootstrap/*.txt manually"
fi

# 2) Submodules (the hyprtasking fork).
info "Fetching submodules"
git -C "$DOT_ROOT" submodule update --init --recursive || warn "submodule init failed"

# 3) Symlink managed configs into ~/.config (backs up anything existing).
info "Linking configs into $CONFIG_HOME"
for d in "${MANAGED_CONFIGS[@]}"; do
    [ -d "$DOT_ROOT/config/$d" ] && link "$DOT_ROOT/config/$d" "$CONFIG_HOME/$d"
done

# 3.5) Wallpaper + path personalization.
# The lockscreen/initial wallpaper points at ~/Pictures/Wallpapers/wall1.jpg — seed
# the vendored copy so it isn't blank. And on a machine whose username isn't "sitish",
# rewrite the few absolute /home/sitish paths baked into the (symlinked)
# illogical-impulse + hyprlock configs so they resolve under this $HOME.
WALL_SRC="$DOT_ROOT/config/quickshell/ii/assets/wallpapers/wall1.jpg"
WALL_DST="$HOME/Pictures/Wallpapers/wall1.jpg"
if [ -f "$WALL_SRC" ] && [ ! -f "$WALL_DST" ]; then
    info "Seeding default wallpaper -> $WALL_DST"
    mkdir -p "$(dirname "$WALL_DST")" && cp "$WALL_SRC" "$WALL_DST"
fi
if [ "$HOME" != "/home/sitish" ]; then
    info "Personalizing baked-in paths (/home/sitish -> $HOME)"
    for f in "$CONFIG_HOME/illogical-impulse/config.json" \
             "$CONFIG_HOME/illogical-impulse/version.json" \
             "$CONFIG_HOME/hypr/hyprlock/colors.conf"; do
        [ -f "$f" ] && sed -i "s|/home/sitish|$HOME|g" "$f"
    done
fi

# 4) Plugins + fork build.
bash "$DOT_ROOT/bootstrap/plugins.sh" || warn "plugin setup had issues"

# 5) System-level tweaks (network/keyring/etc). Idempotent. Skipped with --no-system.
if [ "$WANT_SYSTEM" -eq 1 ]; then
    info "Applying system tweaks (network/keyring) — re-run safe; skip with --no-system"
    bash "$DOT_ROOT/system/system-setup.sh" || warn "system setup had issues (see ARCH-INSTALL.md)"
fi

ok "Install complete. Log into Hyprland (or reload) to apply."
info "PAM keyring auto-unlock is a manual step — see ARCH-INSTALL.md §3"
info "Reflect future edits to GitHub with:  $DOT_ROOT/sync.sh"
