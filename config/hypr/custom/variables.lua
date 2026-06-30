-- ═══════════════════════════════════════════════════════════════════════════
-- Variables — this file is the COMPLETE variable config for your setup.
-- Edit freely here. When this file exists, hyprland/variables.lua is skipped.
-- Updates never touch this file. Check hyprland/variables.lua after an update
-- for any new variables added upstream and copy what you want here.
-- ═══════════════════════════════════════════════════════════════════════════

-- The folder within ~/.config/quickshell containing the config
hl.env("qsConfig", "ii")

-- Apps — change these to your preferred applications
terminal = "~/.config/hypr/hyprland/scripts/launch_first_available.sh 'kitty' 'foot' 'alacritty' 'wezterm' 'konsole' 'kgx' 'uxterm' 'xterm'"
fileManager = "~/.config/hypr/hyprland/scripts/launch_first_available.sh 'dolphin' 'nautilus' 'nemo' 'thunar' 'kitty -1 fish -c yazi'"
codeEditor = "~/.config/hypr/hyprland/scripts/launch_first_available.sh 'windsurf' 'antigravity' 'code' 'codium' 'cursor' 'zed' 'zedit' 'zeditor' 'kate' 'gnome-text-editor' 'emacs' 'command -v nvim && kitty -1 nvim' 'command -v micro && kitty -1 micro'"
officeSoftware = "~/.config/hypr/hyprland/scripts/launch_first_available.sh 'wps' 'onlyoffice-desktopeditors' 'libreoffice'"
textEditor = "~/.config/hypr/hyprland/scripts/launch_first_available.sh 'kate' 'gnome-text-editor' 'emacs'"
volumeMixer = "~/.config/hypr/hyprland/scripts/launch_first_available.sh 'pavucontrol-qt' 'pavucontrol'"
settingsApp = "XDG_CURRENT_DESKTOP=gnome ~/.config/hypr/hyprland/scripts/launch_first_available.sh 'qs -p ~/.config/quickshell/$qsConfig/settings.qml' 'systemsettings' 'gnome-control-center' 'better-control'"
taskManager = "~/.config/hypr/hyprland/scripts/launch_first_available.sh 'gnome-system-monitor' 'plasma-systemmonitor --page-name Processes' 'command -v btop && kitty -1 fish -c btop'"

workspaceGroupSize = 10

-- ═══════════════════════════════════════════════════════════════════════════
-- Custom overrides — add your changes below
-- ═══════════════════════════════════════════════════════════════════════════

-- Pin chromium to the gnome-libsecret password store so its cookie/session
-- encryption key is the same in KDE and Hyprland (the default 'portal' store
-- handed out a different key per desktop -> logged out on every DE switch).
browser = "chromium --password-store=gnome-libsecret"
