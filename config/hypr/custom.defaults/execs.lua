-- Bring up the systemd graphical session under Hyprland.
-- KDE pulls in graphical-session.target via plasma-workspace.target; Hyprland has
-- no equivalent, so xdg-desktop-portal (PartOf=graphical-session.target) and XDG
-- autostart apps never start. Starting hyprland-session.target pulls them in.
-- graphical-session.target refuses *manual* start, but allows being pulled in as a dependency.
hl.on("hyprland.start", function ()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE XDG_SESSION_TYPE && systemctl --user start hyprland-session.target")
    -- Load Xft.dpi so XWayland apps (e.g. kitty forced to X11 for touch) scale at 1.6x
    hl.exec_cmd("xrdb -merge $HOME/.Xresources")
    -- doesn't need manual SUPER+CTRL+3 every boot. Loads once -> no reload-race crash.
    -- Prewarm the quickshell Settings app HIDDEN so SUPER+I opens instantly (see
    -- custom/scripts/settings-toggle.sh). II_SETTINGS_HIDDEN=1 -> starts hidden and
    -- stays alive; the crash-recovery env vars are stripped so the child doesn't
    -- reload shell.qml (the "3 stacked bars" bug). -n keeps it single-instance.
    hl.exec_cmd("sleep 6 && command -v qs >/dev/null && env -u __QUICKSHELL_CRASH_DUMP_PID -u __QUICKSHELL_CRASH_INFO_FD -u __QUICKSHELL_CRASH_SIGNAL II_SETTINGS_HIDDEN=1 qs -p $HOME/.config/quickshell/${qsConfig:-ii}/settings.qml -n")
end)
