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
  plugins.sh          # hyprpm setup + build the hyprtasking fork
config/               # symlinked into ~/.config/
  hypr/               #   Hyprland (Lua config) — keybinds, gestures, overview switcher
  quickshell/         #   the bar/launcher/overview (our owned ii)
  matugen/            #   Material You color generation
  illogical-impulse/  #   ii settings/actions
system/               # system-level (/etc + systemctl) setup — needs sudo
  system-setup.sh     #   NetworkManager-only, gnome-keyring, wifi powersave (idempotent)
  etc/                #   /etc drop-ins captured from this machine
pkgs/
  hyprtasking/        # git submodule → github.com/sitish-kumar/hyprtasking (the fork)
ARCH-INSTALL.md       # bare-metal Arch → this desktop (incl. PAM keyring step)
```

**Two layers:** `config/` is user-level (`~/.config`, symlinked); `system/` is
system-level (`/etc`, `systemctl` — the network/keyring tweaks). `install.sh` runs
both; bare-metal Arch install itself is documented in `ARCH-INSTALL.md`.

## Install (new machine)

**Self-contained — no separate end-4 installer step.** This repo owns the *config*;
the heavy dependency stack (qt6, fonts, portal, pipewire, quickshell) comes from the
`illogical-impulse-*` AUR **packages** listed in `bootstrap/packages.txt`, which
`install.sh` installs for you. (The `ii` config is ours; `illogical-impulse-quickshell-git`
is just the Quickshell *runtime* it runs on — different things.)

```bash
git clone --recurse-submodules https://github.com/sitish-kumar/dotfiles.git ~/Projects/dotfiles
cd ~/Projects/dotfiles
./install.sh        # packages (official+AUR via yay) → submodule → symlink configs → build fork → ydotool
```

**Requires an AUR helper (`yay`)** — the `illogical-impulse-*` meta-packages and
`matugen-bin` are AUR-only. `install.sh` backs up any existing
`~/.config/{hypr,quickshell,matugen,illogical-impulse}` before symlinking ours in,
and enables the `ydotool` user service (needed for clipboard-paste and the on-screen
keyboard).

## Keep it in sync

- **Edit anything** under `~/.config/...` (or `pkgs/hyprtasking`), then:
  ```bash
  ~/Projects/dotfiles/sync.sh "what I changed"
  ```
  → captures the changes, pushes the fork if needed, pushes the repo. **GitHub reflects it.**
- **Pull updates on another machine:** `./update.sh`

## What's customized

**hyprtasking fork** (`pkgs/hyprtasking`): adaptive square overview grid sized by
highest workspace number, "+" create cells, rounded tiles, focus-follows-cursor,
blurred-bg (opt-in), 4-finger re-arm + 3-finger interactivity fixes.

**Overview switcher** (`config/hypr/custom/scripts/overview-switch.sh`): one
overview active at a time — `SUPER+CTRL+1` scrolloverview, `SUPER+CTRL+2/3`
hyprtasking, `SUPER+CTRL+0` off, `SUPER+\`` toggle. 4-finger-up opens it.

**Quickshell (ii)**: emoji grid + recently-used, clipboard timestamps, launcher
tweaks. We own this — no upstream dependency.

**Gestures/keybinds**: 3-finger pinch disabled (Hyprland 0.55 pinch→swipe crash
workaround); see `config/hypr/`.
