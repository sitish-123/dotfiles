-- Pin chromium to the gnome-libsecret password store so its cookie/session
-- encryption key is the same in KDE and Hyprland (the default 'portal' store
-- handed out a different key per desktop -> logged out on every DE switch).
browser = "chromium --password-store=gnome-libsecret"
