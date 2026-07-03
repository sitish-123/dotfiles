#!/usr/bin/env bash
# Exit 0 if an ACTIVE download is likely in progress, else 1.
# Used by services/SessionWarnings.qml to warn before lock/suspend/poweroff.
#
# Why not the old `pidof curl wget aria2c yt-dlp || ls ~/Downloads | grep .part`:
#  - curl/wget are used by tons of background scripts (weather, matugen, updates)
#    -> constant false positives.
#  - a stale *.part / *.crdownload left in ~/Downloads matched forever.
# This version only flags a *dedicated* downloader, or a partial file that was
# actually written in the last minute (i.e. still growing).

# Dedicated download tools actively running
pidof aria2c yt-dlp >/dev/null 2>&1 && exit 0

# Browser / interrupted-download partial file modified within the last minute
if [ -n "$(find "$HOME/Downloads" -maxdepth 1 -type f \
        \( -iname '*.crdownload' -o -iname '*.part' -o -iname '*.download' \) \
        -mmin -1 2>/dev/null)" ]; then
    exit 0
fi

exit 1
