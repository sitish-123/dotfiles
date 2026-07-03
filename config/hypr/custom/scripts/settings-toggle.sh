#!/usr/bin/env bash
# Instant-open Settings.
#
# The quickshell "ii" Settings app (settings.qml) is a standalone ApplicationWindow.
# Cold-spawning `qs -p settings.qml` every time takes multiple seconds. Instead we
# keep ONE persistent instance alive (prewarmed hidden at login, see custom/execs.lua)
# and just flip its visibility over IPC, which is instant.
#
# Behaviour:
#   - If a persistent instance is running -> toggle its visibility (IPC).
#   - If none is running (e.g. it crashed / login prewarm skipped) -> launch it
#     visible as a fresh instance.

SETTINGS_QML="$HOME/.config/quickshell/${qsConfig:-ii}/settings.qml"

# Try to toggle an already-running instance. `qs ipc ... call` returns non-zero
# ("No running instances ...") when nothing is listening on that config path.
if qs ipc -p "$SETTINGS_QML" call settings toggle 2>/dev/null; then
    exit 0
fi

# Nothing running: launch a visible instance.
# Strip the crash-recovery env vars — leaking them makes the child reload
# shell.qml instead of settings.qml (the "3 stacked bars" bug).
env -u __QUICKSHELL_CRASH_DUMP_PID \
    -u __QUICKSHELL_CRASH_INFO_FD \
    -u __QUICKSHELL_CRASH_SIGNAL \
    qs -p "$SETTINGS_QML" -n &
disown
