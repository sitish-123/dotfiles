# dotfiles

My Hyprland desktop — a customized, self-owned fork of the *illogical-impulse*
(end-4) Quickshell setup, plus a forked **hyprtasking** overview plugin. Built to
be re-installable from scratch and easy to keep improving.

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
pkgs/
  hyprtasking/        # git submodule → github.com/sitish-kumar/hyprtasking (the fork)
```

## Install (new machine)

```bash
git clone --recurse-submodules git@github.com:sitish-kumar/dotfiles.git ~/Projects/dotfiles
cd ~/Projects/dotfiles
./install.sh
# AUR bits: yay -S quickshell-git matugen-bin
```

`install.sh` backs up any existing `~/.config/{hypr,quickshell,matugen,illogical-impulse}`
before symlinking ours in.

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
