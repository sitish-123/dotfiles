pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common

// Tracks gpu-screen-recorder state (recording / replay buffer / paused + elapsed).
// EVENT-DRIVEN: scripts/videos/record.sh writes a one-line `state` file on every
// transition (and "off" via its EXIT trap when the recorder exits); we watch it with
// inotify. This used to spawn a bash process every 1-3s FOREVER (RecordingIndicator
// lives in shell.qml, so it ran for the whole session even when nothing recorded).
// Now: zero subprocesses while idle, a pure-JS elapsed counter while active, and a
// low-frequency PID liveness check only as a safety net for a force-killed recorder.
Singleton {
    id: root

    property bool active: false    // a normal recording is in progress
    property bool replay: false    // the replay buffer is armed
    property bool paused: false
    property string scope: ""      // "fullscreen" | "region" | "replay" (what's being captured)
    property double startEpoch: 0
    property int elapsed: 0         // seconds since start
    readonly property bool anyActive: active || replay

    readonly property string stateDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ii-recorder"

    function nowSec() { return Math.floor(Date.now() / 1000); }
    function fmt(s) {
        const m = Math.floor(s / 60), sec = s % 60;
        return `${m}:${sec < 10 ? "0" : ""}${sec}`;
    }

    function stop()        { Quickshell.execDetached([Directories.recordScriptPath, "--stop"]); }
    function togglePause() { Quickshell.execDetached([Directories.recordScriptPath, "--pause"]); }
    function toggleReplay(){ Quickshell.execDetached([Directories.recordScriptPath, "--replay"]); }
    function saveReplay()  { Quickshell.execDetached([Directories.recordScriptPath, "--save-replay"]); }

    function applyState(text) {
        const t = (text || "").trim();
        const parts = t.split(/\s+/);
        if (!t || parts[0] === "off") {
            root.active = false; root.replay = false; root.paused = false;
            root.scope = ""; root.startEpoch = 0; root.elapsed = 0;
            return;
        }
        const mode = parts[0] || "record";
        root.replay = (mode === "replay");
        root.active = (mode !== "replay");
        root.startEpoch = parseInt(parts[1]) || root.nowSec();
        root.paused = (parts[2] === "1");
        root.scope = parts[3] || "fullscreen";
        root.elapsed = Math.max(0, root.nowSec() - root.startEpoch);
    }

    // Ensure the watch dir exists so the FileView can watch `state` before the first
    // recording ever runs (record.sh also mkdir's it, but that's only when recording).
    Process { id: ensureDir; running: true; command: ["mkdir", "-p", root.stateDir] }

    FileView {
        id: stateView
        path: `${root.stateDir}/state`
        watchChanges: true
        onFileChanged: reloadTimer.restart()
        onLoaded: root.applyState(stateView.text())
        onLoadFailed: root.applyState("off")   // no file yet → nothing is recording
    }
    Timer { id: reloadTimer; interval: 80; repeat: false; onTriggered: stateView.reload() }

    // Pure-JS elapsed counter — no subprocess. Only ticks while actively capturing.
    Timer {
        interval: 1000
        running: root.anyActive && !root.paused
        repeat: true
        onTriggered: root.elapsed = Math.max(0, root.nowSec() - root.startEpoch)
    }

    // Safety net: if the recorder is SIGKILL'd, record.sh's EXIT trap can't run to
    // write "off", so the state file would be stale. While we believe something is
    // active, verify the PID twice a minute and clear if it's gone. Idle = no polling.
    Timer {
        interval: 30000
        running: root.anyActive
        repeat: true
        onTriggered: livenessProc.running = true
    }
    Process {
        id: livenessProc
        command: ["bash", "-c",
            'd="${XDG_RUNTIME_DIR:-/tmp}/ii-recorder"; p="$(cat "$d/pid" 2>/dev/null)"; ' +
            '[ -n "$p" ] && kill -0 "$p" 2>/dev/null && echo on || echo off']
        stdout: StdioCollector {
            onStreamFinished: { if (text.trim() === "off") root.applyState("off"); }
        }
    }

    Component.onCompleted: stateView.reload()
}
