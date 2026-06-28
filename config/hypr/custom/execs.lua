-- Bring up the systemd graphical session under Hyprland.
-- KDE pulls in graphical-session.target via plasma-workspace.target; Hyprland has
-- no equivalent, so xdg-desktop-portal (PartOf=graphical-session.target) and XDG
-- autostart apps never start. Starting hyprland-session.target pulls them in.
-- graphical-session.target refuses *manual* start, but allows being pulled in as a dependency.
hl.on("hyprland.start", function ()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE XDG_SESSION_TYPE && systemctl --user start hyprland-session.target")
    -- Load Xft.dpi so XWayland apps (e.g. kitty forced to X11 for touch) scale at 1.6x
    hl.exec_cmd("xrdb -merge $HOME/.Xresources")
end)
