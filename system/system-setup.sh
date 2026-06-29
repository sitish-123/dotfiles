#!/usr/bin/env bash
# System-level setup (the parts that live in /etc and systemctl, not ~/.config).
# Idempotent and safe to re-run: it converges the system to the known-good state,
# so running it on an already-configured machine is a no-op.
#
# Captures the reproducible tweaks from hard-won debugging:
#   - NetworkManager as the SOLE network manager (systemd-networkd masked).
#     This also fixed a 2min -> 16s boot regression and "conflicting networks".
#   - Clears the stale NM "limited connectivity" state (the recurring
#     "connected but no internet" false alarm).
#   - gnome-keyring as secret storage; KWallet disabled.
#   - wifi powersave drop-in.
#
# NOT handled here (too dangerous to script blindly — see ARCH-INSTALL.md):
#   - Bare-metal Arch install (partitioning / base system).
#   - PAM keyring auto-unlock (editing /etc/pam.d can lock you out of login).
#     The script only CHECKS it and prints the lines to add if missing.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

SYS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[ "$(id -u)" -eq 0 ] && die "Run as your normal user (it will sudo where needed), not as root."
have systemctl || die "Not a systemd system — nothing to do."

# 1) /etc drop-ins -----------------------------------------------------------
info "Installing /etc drop-ins"
sudo install -Dm644 "$SYS/etc/NetworkManager/conf.d/wifi-powersave.conf" \
    /etc/NetworkManager/conf.d/wifi-powersave.conf
ok "wifi-powersave.conf"

# 2) Networking: NetworkManager only ----------------------------------------
info "Networking: NetworkManager as the sole manager (masking systemd-networkd)"
sudo systemctl enable --now NetworkManager.service
sudo systemctl mask --now systemd-networkd.service systemd-networkd.socket 2>/dev/null || true
sudo systemctl disable systemd-networkd-wait-online.service 2>/dev/null || true
sudo systemctl enable systemd-resolved.service 2>/dev/null || true
ok "NetworkManager enabled; systemd-networkd masked"

# 3) Clear stale connectivity state (the "no internet" false alarm) ----------
info "Re-checking NM connectivity (clears stale 'limited' state)"
nmcli networking connectivity check >/dev/null 2>&1 || true
ok "connectivity: $(nmcli networking connectivity 2>/dev/null || echo unknown)"

# 4) Secret storage: gnome-keyring on, KWallet off ---------------------------
info "Secret storage: gnome-keyring (KWallet disabled)"
systemctl --user enable --now gnome-keyring-daemon.socket 2>/dev/null || \
    warn "couldn't enable gnome-keyring socket (run inside your graphical session)"
KW="${XDG_CONFIG_HOME:-$HOME/.config}/kwalletrc"
if have kwriteconfig6; then
    kwriteconfig6 --file "$KW" --group Wallet --key Enabled false
elif have kwriteconfig5; then
    kwriteconfig5 --file "$KW" --group Wallet --key Enabled false
else
    mkdir -p "$(dirname "$KW")"
    if grep -q '^\[Wallet\]' "$KW" 2>/dev/null; then
        grep -q '^Enabled=false' "$KW" || warn "set 'Enabled=false' under [Wallet] in $KW manually"
    else
        printf '[Wallet]\nEnabled=false\n' >> "$KW"
    fi
fi
ok "KWallet disabled; gnome-keyring is the keyring"

# 4b) Bluetooth: faster + reliable auto-reconnect ----------------------------
# Defaults make trusted devices (e.g. earbuds) reconnect slowly/inconsistently.
# FastConnectable speeds reconnection; AutoEnable powers the adapter on at boot;
# tighter ReconnectIntervals retry sooner. Keys are unique across sections, so a
# global uncomment-or-set is safe and preserves the rest of the file.
BTCONF=/etc/bluetooth/main.conf
if [ -f "$BTCONF" ]; then
    info "Bluetooth: tuning $BTCONF for faster auto-reconnect"
    set_bt() { # key value  — uncomment/replace the (unique) key in place
        if sudo grep -qiE "^#?\s*$1\s*=" "$BTCONF"; then
            sudo sed -i -E "s|^#?\s*$1\s*=.*|$1 = $2|" "$BTCONF"
        fi
    }
    set_bt FastConnectable true
    set_bt AutoEnable true
    set_bt ReconnectAttempts 7
    set_bt ReconnectIntervals "1,1,2,4,8,16"
    sudo systemctl restart bluetooth.service 2>/dev/null || true
    ok "Bluetooth tuned (FastConnectable/AutoEnable/Reconnect)"
fi

# 4c) Face unlock (howdy) ----------------------------------------------------
# pam_howdy is "sufficient", so a failed face-match just falls through to the
# password — it can't lock you out, which makes auto-wiring hyprlock safe.
if have howdy && [ -f /usr/lib/security/pam_howdy.so ]; then
    info "Face unlock: installing /etc/howdy/config.ini"
    sudo install -Dm644 "$SYS/etc/howdy/config.ini" /etc/howdy/config.ini
    HOWDY_PAM=/etc/pam.d/hyprlock
    if [ -f "$HOWDY_PAM" ] && ! grep -q pam_howdy "$HOWDY_PAM"; then
        info "Wiring pam_howdy into $HOWDY_PAM (lockscreen face unlock)"
        sudo sed -i '1i auth sufficient pam_howdy.so' "$HOWDY_PAM"
    fi
    ok "howdy configured — run 'sudo howdy add' to enroll; set [video] device_path per camera"
else
    warn "howdy not installed (aur:howdy-git) — skipping face unlock wiring"
fi

# 4d) Timeshift backups ------------------------------------------------------
# Seed the schedule template only if unconfigured; never clobber a real config
# (it holds the machine-specific backup device UUID).
if have timeshift; then
    if [ ! -f /etc/timeshift/timeshift.json ] || ! grep -q '"backup_device_uuid" *: *"[^"]' /etc/timeshift/timeshift.json 2>/dev/null; then
        info "Timeshift: seeding schedule template (pick a backup device in the app)"
        sudo install -Dm644 "$SYS/etc/timeshift/timeshift.json" /etc/timeshift/timeshift.json
    fi
    sudo systemctl enable cronie.service 2>/dev/null || true  # timeshift schedules via cron
    ok "timeshift present — open it once to choose the backup device, then snapshots run on schedule"
else
    warn "timeshift not installed — skipping backup setup"
fi

# 5) PAM keyring auto-unlock — CHECK ONLY (never auto-edit /etc/pam.d) --------
DM_PAM="/etc/pam.d/sddm"
if [ -f "$DM_PAM" ] && ! grep -q pam_gnome_keyring "$DM_PAM"; then
    warn "gnome-keyring is NOT wired into $DM_PAM — it won't auto-unlock at login."
    warn "Add these (see ARCH-INSTALL.md), then test login before rebooting:"
    cat <<'EOF'
    auth       optional     pam_gnome_keyring.so
    password   optional     pam_gnome_keyring.so use_authtok      (after the password line)
    session    optional     pam_gnome_keyring.so auto_start       (in the session block)
EOF
fi

ok "System setup complete."
