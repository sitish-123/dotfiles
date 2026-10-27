# dotfiles

My Hyprland desktop — a self-owned Quickshell setup (originally derived from
*illogical-impulse*, now vendored and modified as our own `ii`), plus a forked
**hyprtasking** overview plugin. Built to be re-installable from scratch and easy
to keep improving.

## Layout

```
install.sh            # fresh machine: packages → submodules → plugins/fork → symlink configs
update.sh             # git pull + submodule update + rebuild fork + relink + reload
sync.sh               # capture live ~/.config edits → commit → push (incl. the fork)
lib/common.sh         # shared helpers (logging, symlink-with-backup)
bootstrap/
  packages.txt        # Arch package list (+ AUR notes)
  dev-packages.txt    # OPT-IN dev stack (editors/langs/docker/...) — ./install.sh --dev
  plugins.sh          # hyprpm setup + build the hyprtasking fork
config/               # symlinked into ~/.config/
  hypr/               #   Hyprland (Lua config) — keybinds, gestures, overview switcher
  quickshell/         #   the bar/launcher/overview (our owned ii)
  matugen/            #   Material You color generation
  illogical-impulse/  #   ii settings/actions
system/               # system-level (/etc + systemctl) setup — needs sudo
  system-setup.sh     #   NetworkManager-only, gnome-keyring, face-unlock, timeshift (idempotent)
  etc/                #   /etc drop-ins: NM, howdy (face unlock), timeshift (backup template)
pkgs/
  hyprtasking/        # git submodule → github.com/sitish-123/hyprtasking (the fork)
```

**Two layers:** `config/` is user-level (`~/.config`, symlinked); `system/` is
system-level (`/etc`, `systemctl` — the network/keyring tweaks). `install.sh` runs
both.

## Install (new machine)

**Self-contained — no separate end-4 installer step.** This repo owns the *config*;
the heavy dependency stack (qt6, fonts, portal, pipewire, quickshell) comes from the
`mainstream-*` AUR **packages** listed in `bootstrap/packages.txt`, which
`install.sh` installs for you. (The `ii` config is ours; `quickshell-git`
is just the Quickshell *runtime* it runs on — different things.)

```bash
git clone --recurse-submodules https://github.com/sitish-123/dotfiles.git ~/Projects/dotfiles
cd ~/Projects/dotfiles
./install.sh        # packages (official+AUR) → submodule → symlink configs → build fork → ydotool
```

**Run modes.** `install.sh` first asks whether to run **automatically** (no prompts)
or **manually** (confirm before each phase, and `pacman`/`yay` prompt per transaction
so you can read conflicts and pick providers). Force it with `--auto`/`-y` or
`--manual`/`-i`. Piping into bash defaults to automatic.

**No AUR helper needed up front** — if `yay` is missing, `install.sh` bootstraps
`yay-bin` from the AUR automatically. It does a full `pacman -Syu` (avoids stale-DB
404s), and if the desktop's **critical** packages (`hyprland`, `quickshell`) can't be
installed — e.g. an unresolvable conflict — it **stops before touching your configs**
rather than leaving a half-converted machine. A single conflicting package no longer
aborts the whole batch: the rest install and the culprit is reported at the end.

**Core vs optional.** `bootstrap/packages.txt` is the always-installed **core** (the
desktop itself + toolchain + small utilities). Optional software lives in
`bootstrap/optional-packages.txt`, grouped — **browser** (chromium), **fingerprint**
(fprintd), **ai** (ollama), **backups** (timeshift), **screen-recording**, and
**wallpaper-extras** (mpvpaper/upscayl). In manual mode `install.sh` asks before each
group; in automatic mode it skips them. Force with `--with-optional` / `--no-optional`.
Face unlock (`howdy`, ~6 GB cuda/cudnn) is opt-in via `./install.sh --dev`.

`install.sh` backs up any existing `~/.config/{hypr,quickshell,matugen,illogical-impulse}`
before symlinking ours in, and enables the `ydotool` user service (needed for
clipboard-paste and the on-screen keyboard).

## Keep it in sync

- **Edit anything** under `~/.config/...` (or `pkgs/hyprtasking`), then:
  ```bash
  ~/Projects/dotfiles/sync.sh "what I changed"
  ```
  → captures the changes, pushes the fork if needed, pushes the repo. **GitHub reflects it.**
- **Pull updates on another machine:** `./update.sh`
- **Auto-pull on a secondary machine (opt-in):** a systemd user timer runs `update.sh`
  daily. Don't enable it on the authoring machine (you push from there); enable on
  others:
  ```bash
  mkdir -p ~/.config/systemd/user
  cp ~/Projects/dotfiles/system/user/dotfiles-update.{service,timer} ~/.config/systemd/user/
  systemctl --user enable --now dotfiles-update.timer
  ```
- **CI:** `.github/workflows/lint.yml` runs on every push — `bash -n` + shellcheck on
  scripts, JSON validation, and `bootstrap/lint-qml.sh` (catches e.g. QML using
  `ScriptModel` without `import Quickshell`, the blank-page bug).

## What's customized

**hyprtasking fork** (`pkgs/hyprtasking`): adaptive square overview grid sized by
highest workspace number, "+" create cells, rounded tiles, focus-follows-cursor,
blurred-bg (opt-in), 4-finger re-arm + 3-finger interactivity fixes.

**Overview control** (`config/hypr/custom/scripts/overview-switch.sh`): the
hyprtasking fork is the one overview plugin — `SUPER+CTRL+1` on, `SUPER+CTRL+0`
off, `SUPER+\`` toggle (open/close). 4-finger-up opens it.

**Quickshell (ii)**: emoji grid + recently-used, clipboard timestamps, launcher
tweaks — our modifications on top of the vendored *illogical-impulse* config (see
Credits below).

**Gestures/keybinds**: 3-finger pinch disabled (Hyprland 0.55 pinch→swipe crash
workaround); see `config/hypr/`.

`profiles/sitish/` holds my own live Hyprland and kitty setup, separate from the rice that
`install.sh` installs. `config/fish/` is my fish config.

## Bare-metal install

The OS install itself is **not scripted** (partitioning someone's disk from a script is how
you lose data) — use `archinstall`, then this repo handles the rest.

### 1. Base Arch (manual, once)

Boot the Arch ISO and run `archinstall`. Reasonable choices for this setup:
- **Profile:** Minimal (we install the desktop ourselves) — or Desktop → none.
- **Audio:** Pipewire.
- **Network:** **NetworkManager** (important — this repo assumes NM, not networkd).
- **Bootloader:** systemd-boot or GRUB (either is fine).
- Create your user, enable sudo.

Reboot into the new system, log in on a TTY, connect (`nmtui`), then:

```bash
sudo pacman -S --needed git base-devel
```

`install.sh` bootstraps `yay-bin` if it is missing. Then follow **Install (new machine)**
above, and run `./system/system-setup.sh` for the system tweaks (idempotent).

### 2. Face unlock (howdy) — per-machine enrollment

`howdy-git` + the config are installed by `install.sh`/`system-setup.sh`, and
`pam_howdy` is wired into `/etc/pam.d/hyprlock` (it's `sufficient`, so a failed
match just falls back to the password — it can't lock you out). Two machine-specific
steps remain because face data and the camera node don't transfer:

```bash
ls /dev/video*                       # find the IR camera; try candidates
sudo nano /etc/howdy/config.ini      # set [video] device_path to it
sudo howdy add                       # enroll your face (re-do per machine)
```

### 3. Backups (timeshift)

`timeshift` is installed and a schedule template seeded to `/etc/timeshift/timeshift.json`
(only if unconfigured). Open **timeshift** once and pick the backup device — it writes
the machine-specific UUID, after which snapshots run on the daily/weekly/monthly
schedule via cron.

### 4. Secret storage — PAM keyring auto-unlock (manual, careful)

`system-setup.sh` enables gnome-keyring and disables KWallet, but it will **not**
edit `/etc/pam.d` for you (a bad edit there can lock you out of login). To make the
keyring unlock automatically with your login password, add these to your display
manager's PAM file — here **`/etc/pam.d/sddm`**:

```
auth       optional     pam_gnome_keyring.so
password   optional     pam_gnome_keyring.so use_authtok
session    optional     pam_gnome_keyring.so auto_start
```

Place `auth` near the other auth lines, `password` after the main `password` line
(`use_authtok` so it reuses the just-entered password), and `session` in the session
block. **Keep a second TTY logged in and test a fresh login before rebooting.**

### What the system layer reproduces

- **NetworkManager only** — `systemd-networkd` + its socket masked, `wait-online`
  disabled. Fixed a 2min→16s boot regression and the "conflicting networks" issue.
- **No-internet false alarm** — re-runs `nmcli networking connectivity check` to
  clear stale `limited` state (IPv4 was always fine; the state was wrong).
- **gnome-keyring** secret storage, **KWallet off**.
- **wifi powersave** drop-in (`/etc/NetworkManager/conf.d/wifi-powersave.conf`).

## Credits & License

This desktop stands on the work of others. Huge thanks to the projects below — please
star/sponsor them.

### Desktop config (`config/`)

- **[end-4 / dots-hyprland](https://github.com/end-4/dots-hyprland)** — *illogical-impulse*, **GPL-3.0**.
  The Quickshell desktop in `config/quickshell/ii` is **derived from and modified on top of**
  illogical-impulse. Sponsor: <https://github.com/sponsors/end-4>
- **[caelestia-dots/shell](https://github.com/caelestia-dots/shell)** — **GPL-3.0**.
  Portions of `config/quickshell/ii/modules/common/Icons.qml` originate here.

### Hyprland plugins

- **[Raymond Bian (raybbian) / hyprtasking](https://github.com/raybbian/hyprtasking)** — **BSD-3-Clause**.
  `pkgs/hyprtasking` is a fork; the original copyright (© 2024 Raymond Bian) is retained in
  that submodule's `LICENSE`.

### Tools & themes (installed as packages, not vendored)

- [Quickshell](https://github.com/quickshell-mirror/quickshell) — the runtime that renders the config
- [matugen](https://github.com/InioX/matugen) — Material You color generation
- [kde-material-you-colors](https://github.com/luisbocanegra/kde-material-you-colors)
- [Bibata Cursor](https://github.com/ful1e5/Bibata_Cursor)

### This repository's own work

The installer/maintenance scripts and system tweaks — `install.sh`, `update.sh`, `sync.sh`,
`bootstrap/`, `system/`, and the `hyprtasking` fork's added features — are authored by the
repository owner.

Because this repository contains and modifies GPL-3.0 work, it is released under the
**GPL-3.0** (see [LICENSE](LICENSE)).
