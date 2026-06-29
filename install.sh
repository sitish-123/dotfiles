#!/usr/bin/env bash
# Fresh-machine setup: packages -> submodule -> plugins/fork -> symlink configs -> system.
# Idempotent: safe to re-run. Existing real configs are backed up before linking.
#
# Run modes (pick interactively, or force with a flag):
#   automatic (--auto/-y) : every phase runs with --noconfirm, no questions asked.
#   manual    (--manual/-i): confirm before each phase, AND pacman/yay prompt per
#                            transaction so you can read conflicts and pick providers.
# Other flags: --no-system (skip /etc tweaks), --dev (also install dev-packages.txt).
source "$(dirname "$0")/lib/common.sh"

WANT_SYSTEM=1; WANT_DEV=0; ASSUME_YES=""
for a in "$@"; do
    case "$a" in
        --no-system)     WANT_SYSTEM=0 ;;
        --dev)           WANT_DEV=1 ;;
        --auto|-y|--yes) ASSUME_YES=1 ;;
        --manual|-i)     ASSUME_YES=0 ;;
        -h|--help)       sed -n '2,10p' "$0"; exit 0 ;;
    esac
done

# --- Run mode ---------------------------------------------------------------
# Default to a prompt on a real terminal; pipes (curl | bash) fall back to automatic.
if [ -z "$ASSUME_YES" ]; then
    if [ -t 0 ]; then
        printf '\033[1;36m?\033[0m Run mode — [A]utomatic (no prompts) or [M]anual (confirm each step)? [A/m] '
        read -r _m || _m=A
        case "${_m:-A}" in [Mm]*) ASSUME_YES=0 ;; *) ASSUME_YES=1 ;; esac
    else
        ASSUME_YES=1
    fi
fi
NOCONFIRM=""; [ "$ASSUME_YES" -eq 1 ] && NOCONFIRM="--noconfirm"
[ "$ASSUME_YES" -eq 1 ] && info "Mode: automatic (no prompts)" || info "Mode: manual (you confirm each step)"

# ask_yes <prompt> : automatic -> always yes; manual -> ask. Returns 0 (yes) / 1 (no).
ask_yes() {
    [ "$ASSUME_YES" -eq 1 ] && return 0
    local a; read -rp "$(printf '\033[1;36m?\033[0m %s [Y/n] ' "$1")" a || return 1
    case "${a:-Y}" in [Nn]*) return 1 ;; *) return 0 ;; esac
}

# --- Package helpers --------------------------------------------------------
FAILED_PKGS=()

# _pm <pacman|yay> <op...> : run the helper with the shared --needed/$NOCONFIRM tail.
_pm() {
    local helper="$1"; shift
    case "$helper" in
        pacman) sudo pacman "$@" --needed $NOCONFIRM ;;
        yay)    yay        "$@" --needed $NOCONFIRM ;;
    esac
}

# resolve_failure <helper> <pkg> : a package failed to install (usually a conflict).
# On a real terminal, offer to retry INTERACTIVELY — running pacman/yay WITHOUT
# --noconfirm, so their own "X and Y are in conflict. Remove Y? [y/N]" prompt lets you
# remove the conflicting package and continue — or skip it, or abort the whole run.
# Returns 0 if the package ended up installed, 1 if skipped. Non-interactive -> skip.
resolve_failure() {
    local helper="$1" pkg="$2" ans
    [ -t 0 ] || return 1
    while true; do
        printf '\033[1;33m!!\033[0m %s failed (likely a conflict). [r]etry interactively / [s]kip / [a]bort? [r/s/a] ' "$pkg"
        read -r ans || ans=s
        case "${ans:-r}" in
            r|R) if [ "$helper" = pacman ]; then sudo pacman -S --needed "$pkg"; else yay -S --needed "$pkg"; fi \
                    && return 0 || warn "$pkg still not installed — try again, skip, or abort" ;;
            s|S) return 1 ;;
            a|A) die "Aborted at conflicting package: $pkg (resolve it, then re-run ./install.sh)" ;;
            *)   : ;;
        esac
    done
}

# install_batch <helper> <label> <pkgs...> : one fast `-Syu` pass; if it fails (a single
# unresolvable conflict aborts the WHOLE transaction), retry each package alone so the
# rest still land and the culprit is named. Each lone failure goes through resolve_failure
# (interactive conflict removal); whatever's still unresolved lands in FAILED_PKGS.
install_batch() {
    local helper="$1" label="$2"; shift 2
    [ "$#" -gt 0 ] || return 0
    if _pm "$helper" -Syu "$@"; then return 0; fi
    warn "$label: batch install failed (conflict / 404 / dropped name) — retrying one-by-one to isolate it"
    local p
    for p in "$@"; do
        if _pm "$helper" -S "$p"; then continue; fi
        resolve_failure "$helper" "$p" || { warn "  ✗ $p (unresolved)"; FAILED_PKGS+=("$p"); }
    done
}

# ensure_yay : bootstrap yay-bin from the AUR when no helper is present. WITHOUT this a
# fresh Arch box silently skips every AUR meta-package — i.e. the entire desktop.
ensure_yay() {
    have yay && return 0
    info "No AUR helper found — bootstrapping yay-bin from the AUR"
    sudo pacman -S --needed $NOCONFIRM git base-devel || { warn "couldn't install yay build deps"; return 1; }
    local tmp; tmp="$(mktemp -d)"
    if git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin" \
       && ( cd "$tmp/yay-bin" && makepkg -si $NOCONFIRM ); then
        rm -rf "$tmp"; have yay
    else
        warn "yay bootstrap failed — AUR packages can't be installed automatically"
        rm -rf "$tmp"; return 1
    fi
}

# install_pkgs <packages-file> <label>
install_pkgs() {
    local file="$1" label="$2"
    [ -f "$file" ] || { warn "missing $file"; return; }
    mapfile -t OFFICIAL < <(grep -vE '^\s*#|^\s*$|^aur:' "$file")
    mapfile -t AUR < <(grep '^aur:' "$file" | sed 's/^aur://')
    info "Installing ${#OFFICIAL[@]} official $label packages"
    install_batch pacman "$label official" "${OFFICIAL[@]}"
    if [ "${#AUR[@]}" -gt 0 ]; then
        have yay || ensure_yay || true
        if have yay; then
            info "Installing ${#AUR[@]} AUR $label packages"
            install_batch yay "$label AUR" "${AUR[@]}"
        else
            warn "No AUR helper — these desktop packages were NOT installed: ${AUR[*]}"
            FAILED_PKGS+=("${AUR[@]}")
        fi
    fi
}

info "dotfiles install — root: $DOT_ROOT"

# 1) Packages ----------------------------------------------------------------
DID_PKG=0
if have pacman; then
    if ask_yes "Install packages now (official + AUR via yay; full -Syu upgrade)?"; then
        install_pkgs "$DOT_ROOT/bootstrap/packages.txt" "base"
        [ "$WANT_DEV" -eq 1 ] && install_pkgs "$DOT_ROOT/bootstrap/dev-packages.txt" "dev"
        # ydotool daemon (virtual keyboard: clipboard paste, on-screen keyboard)
        have ydotoold && systemctl --user enable --now ydotool 2>/dev/null || \
            warn "couldn't enable ydotool daemon (needed for paste/OSK) — check uinput perms"
        DID_PKG=1
    else
        warn "Skipping package installation (your choice)."
    fi

    # Critical-package gate. If the desktop literally cannot start, STOP here — before we
    # symlink over a possibly-working ~/.config or print a false "success". Only enforced
    # when we actually attempted the package phase. `pacman -T` is provides-aware, so it
    # sees quickshell satisfied by quickshell-git.
    if [ "$DID_PKG" -eq 1 ]; then
        MISSING_CRIT=()
        for c in hyprland quickshell; do
            pacman -T "$c" >/dev/null 2>&1 || MISSING_CRIT+=("$c")
        done
        if [ "${#MISSING_CRIT[@]}" -gt 0 ]; then
            warn "CRITICAL packages missing: ${MISSING_CRIT[*]} — the desktop cannot start."
            warn "Most likely a package CONFLICT or stale mirrors. To see and resolve it, run:"
            warn "    yay -Syu ${MISSING_CRIT[*]}     # read the conflict; pick a provider or remove the conflicting pkg"
            warn "    sudo pacman -Syyu               # if it's 404s from stale mirrors, then re-run ./install.sh"
            die  "Stopping before symlink/plugins so the machine is left as-is, not half-converted."
        fi
    fi
else
    warn "Not an Arch system — install packages from bootstrap/*.txt manually"
fi

# 2) Submodules (the hyprtasking fork) --------------------------------------
if ask_yes "Fetch the hyprtasking fork submodule?"; then
    info "Fetching submodules"
    git -C "$DOT_ROOT" submodule update --init --recursive || warn "submodule init failed"
fi

# 3) Symlink managed configs into ~/.config (backs up anything existing) ------
if ask_yes "Symlink configs into $CONFIG_HOME (existing real configs are backed up)?"; then
    info "Linking configs into $CONFIG_HOME"
    for d in "${MANAGED_CONFIGS[@]}"; do
        [ -d "$DOT_ROOT/config/$d" ] && link "$DOT_ROOT/config/$d" "$CONFIG_HOME/$d"
    done

    # Wallpaper + path personalization. The lockscreen/initial wallpaper points at
    # ~/Pictures/Wallpapers/wall1.jpg — seed the vendored copy so it isn't blank. And on
    # a machine whose username isn't "sitish", rewrite the few absolute /home/sitish paths
    # baked into the (symlinked) illogical-impulse + hyprlock configs.
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
fi

# 4) Plugins + fork build ----------------------------------------------------
if ask_yes "Build Hyprland plugins + the hyprtasking fork?"; then
    bash "$DOT_ROOT/bootstrap/plugins.sh" || warn "plugin setup had issues"
fi

# 5) System-level tweaks (network/keyring/etc). Idempotent. Skipped with --no-system.
if [ "$WANT_SYSTEM" -eq 1 ] && ask_yes "Apply system tweaks (network/keyring/bluetooth — needs sudo)?"; then
    info "Applying system tweaks (network/keyring) — re-run safe"
    bash "$DOT_ROOT/system/system-setup.sh" || warn "system setup had issues (see ARCH-INSTALL.md)"
fi

# --- Summary ----------------------------------------------------------------
if [ "${#FAILED_PKGS[@]}" -gt 0 ]; then
    warn "Optional packages that did NOT install (${#FAILED_PKGS[@]}): ${FAILED_PKGS[*]}"
    warn "Retry or inspect the conflict with:  yay -S ${FAILED_PKGS[*]}"
fi
ok "Install complete. Log into Hyprland (or reload) to apply."
info "PAM keyring auto-unlock is a manual step — see ARCH-INSTALL.md §3"
info "Reflect future edits to GitHub with:  $DOT_ROOT/sync.sh"
