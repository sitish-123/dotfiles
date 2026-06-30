#!/usr/bin/env bash
# Fresh-machine setup: packages -> submodule -> plugins/fork -> symlink configs -> system.
# Idempotent: safe to re-run. Existing real configs are backed up before linking.
#
# Run modes (pick interactively, or force with a flag):
#   automatic (--auto/-y) : every phase runs with --noconfirm, no questions asked.
#   manual    (--manual/-i): confirm before each phase, AND pacman/yay prompt per
#                            transaction so you can read conflicts and pick providers.
# Other flags:
#   --no-system : skip /etc tweaks.
#   --dev       : also offer the dev-packages.txt groups (editors / languages /
#                 containers / db / android / face-unlock). Manual mode asks per
#                 group; automatic mode installs them all (--dev is the opt-in).
#   --with-optional / --no-optional : install or skip ALL optional packages (base AND
#                 dev) without asking. Default: in manual mode ask ONE gate question for
#                 optional software, then (if accepted) ask per package; automatic mode
#                 skips base optional and installs dev packages only when --dev.
source "$(dirname "$0")/lib/common.sh"

WANT_SYSTEM=1; WANT_DEV=0; ASSUME_YES=""; WANT_OPTIONAL=""
for a in "$@"; do
    case "$a" in
        --no-system)      WANT_SYSTEM=0 ;;
        --dev)            WANT_DEV=1 ;;
        --auto|-y|--yes)  ASSUME_YES=1 ;;
        --manual|-i)      ASSUME_YES=0 ;;
        --with-optional)  WANT_OPTIONAL=1 ;;
        --no-optional)    WANT_OPTIONAL=0 ;;
        -h|--help)        sed -n '2,16p' "$0"; exit 0 ;;
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

# detect_conflict <helper> <pkg> : print the name of the INSTALLED package that blocks
# <pkg> from installing, or nothing. We re-run the install answering "no" to every prompt
# (printf 'n') so pacman/yay reveals its "X and Y are in conflict. Remove Y? [y/N]" line
# without actually changing anything, then parse the package to remove out of it.
detect_conflict() {
    local helper="$1" pkg="$2" out
    out="$( printf 'n\nn\nn\n' | { [ "$helper" = pacman ] && sudo pacman -S --needed "$pkg" || yay -S --needed "$pkg"; } 2>&1 )"
    # "<new> and <installed> are in conflict. Remove <installed>?" — prefer the Remove line.
    printf '%s\n' "$out" | grep -oiE 'Remove [[:alnum:]@._+-]+' | head -1 | awk '{print $2}' && return 0
    printf '%s\n' "$out" | grep -oiE '[[:alnum:]@._+-]+ and [[:alnum:]@._+-]+ are in conflict' | head -1 | awk '{print $3}'
}

# resolve_failure <helper> <pkg> : a package failed to install (usually a conflict).
# On a real terminal, offer to:
#   [r] retry INTERACTIVELY — pacman/yay WITHOUT --noconfirm, so their own
#       "X and Y are in conflict. Remove Y? [y/N]" prompt removes the conflict (dep-checked).
#   [f] FORCE-remove the conflicting installed package with `pacman -Rdd` then retry. -Rdd
#       skips ALL dependency checks, so it can break packages that depend on the removed one
#       — we auto-detect the culprit, show it, and require an explicit y before doing it.
#   [s] skip   [a] abort.
# Returns 0 if the package ended up installed, 1 if skipped. Non-interactive -> skip
# (we never fire -Rdd unattended — too easy to brick a system).
resolve_failure() {
    local helper="$1" pkg="$2" ans conflict yn
    [ -t 0 ] || return 1
    while true; do
        printf '\033[1;33m!!\033[0m %s failed (likely a conflict). [r]etry interactively / [f]orce-remove conflict (-Rdd) / [s]kip / [a]bort? [r/f/s/a] ' "$pkg"
        read -r ans || ans=s
        case "${ans:-r}" in
            r|R) if [ "$helper" = pacman ]; then sudo pacman -S --needed "$pkg"; else yay -S --needed "$pkg"; fi \
                    && return 0 || warn "$pkg still not installed — try again, skip, or abort" ;;
            f|F) info "Detecting which installed package conflicts with $pkg…"
                 conflict="$(detect_conflict "$helper" "$pkg")"
                 if [ -z "$conflict" ]; then
                     printf '\033[1;33m??\033[0m couldn'\''t auto-detect it. Enter the package to remove with -Rdd (empty to cancel): '
                     read -r conflict
                 fi
                 [ -n "$conflict" ] || { warn "no package given — not removing"; continue; }
                 warn "About to: sudo pacman -Rdd --noconfirm $conflict   (skips dependency checks — may break packages needing '$conflict')"
                 printf '\033[1;36m?\033[0m Force-remove '\''%s'\'' and retry %s? [y/N] ' "$conflict" "$pkg"
                 read -r yn
                 case "${yn:-N}" in
                     y|Y) sudo pacman -Rdd --noconfirm "$conflict" || { warn "removal of $conflict failed"; continue; }
                          if [ "$helper" = pacman ]; then sudo pacman -S --needed --noconfirm "$pkg"; else yay -S --needed --noconfirm "$pkg"; fi \
                              && { ok "$pkg installed after removing $conflict"; return 0; } \
                              || warn "$pkg still failing after removing $conflict — try again, skip, or abort" ;;
                     *)   info "cancelled — $conflict left installed" ;;
                 esac ;;
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

# _install_set <label> <pkgs...> : install a mixed official/aur list (splits on aur:).
_install_set() {
    local label="$1"; shift
    local off=() aur=() p
    for p in "$@"; do case "$p" in aur:*) aur+=("${p#aur:}") ;; *) off+=("$p") ;; esac; done
    [ "${#off[@]}" -gt 0 ] && install_batch pacman "$label official" "${off[@]}"
    if [ "${#aur[@]}" -gt 0 ]; then
        have yay || ensure_yay || true
        if have yay; then install_batch yay "$label AUR" "${aur[@]}"
        else warn "No AUR helper — skipped: ${aur[*]}"; FAILED_PKGS+=("${aur[@]}"); fi
    fi
}

# install_optional <file> [auto_default] [gate_label] : two-level opt-in.
#   1) ONE gate question for the whole file. Decline it and NOTHING else is asked or
#      installed — no per-package prompts at all.
#      --with-optional -> gate yes (and install every package, no per-pkg prompts);
#      --no-optional   -> gate no;
#      automatic/non-interactive -> auto_default ("skip" [default] / "install");
#      manual/TTY      -> ask once.
#   2) If the gate passed AND we're interactive (not forced/automatic), ask per PACKAGE,
#      showing that package's group description for context. Forced/automatic installs all.
# Walks "# group: name | desc" sections to attach a description to each package line.
install_optional() {
    local file="$1" auto_default="${2:-skip}" gate_label="${3:-optional packages}"
    [ -f "$file" ] || return 0

    # --- 1) the single gate -------------------------------------------------
    # gate=0 -> proceed, gate=1 -> skip everything. ask_per=1 -> prompt per package.
    local gate ask_per=0
    case "$WANT_OPTIONAL" in
        1) gate=0 ;;                                   # --with-optional: all, no prompts
        0) gate=1 ;;                                   # --no-optional: none
        *) if [ "$ASSUME_YES" -eq 1 ] || [ ! -t 0 ]; then
               [ "$auto_default" = install ] && gate=0 || gate=1
           elif ask_yes "Install $gate_label? (you'll pick each one)"; then
               gate=0; ask_per=1
           else
               gate=1
           fi ;;
    esac
    if [ "$gate" -ne 0 ]; then
        info "Optional ($gate_label) — skipped"
        return 0
    fi

    # --- 2) gate passed: collect packages (per-package ask when interactive) -
    local gdesc="" line pkg
    local -a chosen=()
    while IFS= read -r line; do
        if [[ "$line" =~ ^#[[:space:]]*group:[[:space:]]*[^|]+\|[[:space:]]*(.*)$ ]]; then
            gdesc="$(echo "${BASH_REMATCH[1]}" | sed 's/[[:space:]]*$//')"
        elif [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "${line//[[:space:]]/}" ]]; then
            continue
        else
            pkg="${line#aur:}"
            if [ "$ask_per" -eq 1 ]; then
                ask_yes "  $pkg — ${gdesc:-optional}?" && chosen+=("$line")
            else
                chosen+=("$line")                      # forced/automatic: take all
            fi
        fi
    done < "$file"

    if [ "${#chosen[@]}" -gt 0 ]; then
        info "Optional ($gate_label) — installing ${#chosen[@]} package(s)"
        _install_set "optional" "${chosen[@]}"
    else
        info "Optional ($gate_label) — nothing selected"
    fi
}

info "dotfiles install — root: $DOT_ROOT"

# 1) Packages ----------------------------------------------------------------
DID_PKG=0
if have pacman; then
    if ask_yes "Install packages now (official + AUR via yay; full -Syu upgrade)?"; then
        install_pkgs "$DOT_ROOT/bootstrap/packages.txt" "base"
        # dev tooling is installed below (grouped, with the other optional groups)
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

        # Optional software (browser, fingerprint, AI, backups, recording, wallpaper extras).
        # ONE gate question; if you accept it, you're asked per package. Declined or in
        # automatic mode -> nothing here is installed (override with --with-optional).
        install_optional "$DOT_ROOT/bootstrap/optional-packages.txt" skip \
            "optional packages (browser, fingerprint, AI, backups, recording, wallpaper extras)"

        # Dev tooling (editors / languages / containers / db / android / face-unlock),
        # only when --dev is given. Same two-level flow: manual asks the gate then per
        # package; automatic+--dev installs all (--dev is the opt-in); --no-optional skips.
        [ "$WANT_DEV" -eq 1 ] && install_optional "$DOT_ROOT/bootstrap/dev-packages.txt" install \
            "dev packages (editors / languages / containers / db / android / face-unlock)"
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

    # Seed custom/ lua files from custom.defaults/ — only if the file doesn't exist yet.
    # custom/*.lua is gitignored; updates never overwrite them. Edit custom/ freely.
    CUSTOM_SRC="$DOT_ROOT/config/hypr/custom.defaults"
    CUSTOM_DST="$DOT_ROOT/config/hypr/custom"
    if [ -d "$CUSTOM_SRC" ]; then
        mkdir -p "$CUSTOM_DST"
        for f in "$CUSTOM_SRC"/*.lua; do
            dst="$CUSTOM_DST/$(basename "$f")"
            [ -f "$dst" ] || { cp "$f" "$dst"; info "Seeded custom/$(basename "$f") from defaults"; }
        done
    fi

    # AI app launchers: Gemini + ChatGPT as chromium PWAs, Claude Code in a terminal.
    # Self-built (no third-party packages), idempotent. Needs a Chromium-based browser
    # for the PWAs (the optional 'browser' group's chromium); skips them otherwise.
    bash "$DOT_ROOT/bootstrap/webapps/setup-webapps.sh" || warn "AI app launcher setup had issues"
fi

# 4) Plugins + fork build ----------------------------------------------------
if ask_yes "Build Hyprland plugins + the hyprtasking fork?"; then
    bash "$DOT_ROOT/bootstrap/plugins.sh" || warn "plugin setup had issues"
fi

# 4b) Native AI sidebar (Qt6 + WebEngine + LayerShellQt) -> ~/.local/bin/ai-sidebar.
chmod +x "$DOT_ROOT/bootstrap/build-ai-sidebar.sh" 2>/dev/null
bash "$DOT_ROOT/bootstrap/build-ai-sidebar.sh" || warn "ai-sidebar build had issues"

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
