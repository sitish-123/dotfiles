#!/bin/sh
# Persistent BlueZ pairing agent for the quickshell ii desktop.
#
# WHY THIS EXISTS: BlueZ requires a registered pairing agent to complete ANY
# pairing — even no-PIN "Just Works" devices (earbuds, speakers). Desktop envs
# normally get one from blueman-applet / gnome-bluetooth, but ii ships neither:
# its sidebar/settings only call device.pair()/connect() over D-Bus and rely on
# a system agent existing. With no agent, pairing half-completes then drops with
# no PIN/popup — looks completely "bugged". This service IS that missing agent.
#
# It keeps bluetoothctl alive (stdin held open) so the NoInputNoOutput agent it
# registers stays registered for the life of the session.
{
    printf 'agent NoInputNoOutput\n'
    printf 'default-agent\n'
    printf 'pairable on\n'
    tail -f /dev/null   # hold stdin open so bluetoothctl never exits
} | exec bluetoothctl
