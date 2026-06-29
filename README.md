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
  hyprtasking/        # git submodule → github.com/sitish-kumar/hyprtasking (the fork)
ARCH-INSTALL.md       # bare-metal Arch → this desktop (incl. PAM keyring step)
```

**Two layers:** `config/` is user-level (`~/.config`, symlinked); `system/` is
system-level (`/etc`, `systemctl` — the network/keyring tweaks). `install.sh` runs
both; bare-metal Arch install itself is documented in `ARCH-INSTALL.md`.

## Install (new machine)

**Self-contained — no separate end-4 installer step.** This repo owns the *config*;
the heavy dependency stack (qt6, fonts, portal, pipewire, quickshell) comes from the
`mainstream-*` AUR **packages** listed in `bootstrap/packages.txt`, which
`install.sh` installs for you. (The `ii` config is ours; `quickshell-git`
is just the Quickshell *runtime* it runs on — different things.)

```bash
git clone --recurse-submodules https://github.com/sitish-kumar/dotfiles.git ~/Projects/dotfiles
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

## Credits & License

The desktop config (`config/quickshell/ii`) is **derived from
[end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)** (*illogical-impulse*,
GPL-3.0), with bits from [caelestia-dots/shell](https://github.com/caelestia-dots/shell)
(GPL-3.0); the overview plugin is a fork of
[raybbian/hyprtasking](https://github.com/raybbian/hyprtasking) (BSD-3-Clause). Full
attribution is in **[CREDITS.md](CREDITS.md)**.

Released under **GPL-3.0** (see [LICENSE](LICENSE)) — required by the copyleft of the
vendored work above.
