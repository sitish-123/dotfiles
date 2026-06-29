pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common

// Tracks gpu-screen-recorder state (recording / replay buffer / paused + elapsed)
// by polling the process and the state files written by scripts/videos/record.sh.
// Drives the on-screen RecordingIndicator and exposes control helpers.
Singleton {
    id: root

    property bool active: false    // a normal recording is in progress
    property bool replay: false    // the replay buffer is armed
    property bool paused: false
    property string scope: ""      // "fullscreen" | "region" | "replay" (what's being captured)
    property double startEpoch: 0
    property int elapsed: 0         // seconds since start
    readonly property bool anyActive: active || replay

    function nowSec() { return Math.floor(Date.now() / 1000); }
    function fmt(s) {
        const m = Math.floor(s / 60), sec = s % 60;
        return `${m}:${sec < 10 ? "0" : ""}${sec}`;
    }

    function stop()        { Quickshell.execDetached([Directories.recordScriptPath, "--stop"]); }
    function togglePause() { Quickshell.execDetached([Directories.recordScriptPath, "--pause"]); }
    function toggleReplay(){ Quickshell.execDetached([Directories.recordScriptPath, "--replay"]); }
    function saveReplay()  { Quickshell.execDetached([Directories.recordScriptPath, "--save-replay"]); }

    Process {
        id: poll
        command: ["bash", "-c",
            'd="${XDG_RUNTIME_DIR:-/tmp}/ii-recorder"; p="$(cat "$d/pid" 2>/dev/null)"; ' +
            'if [ -n "$p" ] && kill -0 "$p" 2>/dev/null; then ' +
            '  printf "on %s %s %s %s" "$(cat "$d/mode" 2>/dev/null)" "$(cat "$d/started" 2>/dev/null)" "$([ -f "$d/paused" ] && echo 1 || echo 0)" "$(cat "$d/scope" 2>/dev/null)"; ' +
            'else printf off; fi']
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(/\s+/);
                if (parts[0] !== "on") {
                    root.active = false; root.replay = false; root.paused = false;
                    root.scope = ""; root.startEpoch = 0; root.elapsed = 0;
                    return;
                }
                const mode = parts[1] || "record";
                root.replay = (mode === "replay");
                root.active = (mode !== "replay");
                root.startEpoch = parseInt(parts[2]) || root.nowSec();
                root.paused = (parts[3] === "1");
                root.scope = parts[4] || "fullscreen";
                root.elapsed = Math.max(0, root.nowSec() - root.startEpoch);
            }
        }
    }
    Timer {
        // 1s while recording (the elapsed counter needs it); back off to 3s when idle —
        // then we're only polling to notice a recording started, which isn't urgent.
        interval: root.anyActive ? 1000 : 3000
        running: true; repeat: true
        onTriggered: {
            if (root.anyActive && !root.paused)
                root.elapsed = Math.max(0, root.nowSec() - root.startEpoch);
            poll.running = true;
        }
    }
    Component.onCompleted: poll.running = true
}
