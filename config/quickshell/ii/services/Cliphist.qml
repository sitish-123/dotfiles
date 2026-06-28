pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    // property string cliphistBinary: FileUtils.trimFileProtocol(`${Directories.home}/.cargo/bin/stash`)
    property string cliphistBinary: "cliphist"
    property real pasteDelay: 0.05
    property string pressPasteCommand: "ydotool key -d 1 29:1 47:1 47:0 29:0"
    property bool sloppySearch: Config.options?.search.sloppy ?? false
    property real scoreThreshold: 0.2
    property list<string> entries: []
    // Sidecar timestamps recorded by hyprland/scripts/cliphist-store.sh.
    property var times: ({})   // { cliphistId: epochSeconds }
    function entryTime(entry) {
        return root.times[`${entry}`.split("\t")[0]] ?? 0;
    }
    function entryTimeLabel(entry) {
        const t = root.entryTime(entry);
        return t ? new Date(t * 1000).toLocaleTimeString(Qt.locale(), "HH:mm") : "";
    }
    function entrySection(entry) {
        if (root.isPinned(entry)) return "Pinned";
        const t = root.entryTime(entry);
        if (!t) return "Earlier";
        const d = new Date(t * 1000), now = new Date();
        const sod = x => new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime();
        const diff = Math.round((sod(now) - sod(d)) / 86400000);
        if (diff <= 0) return "Today";
        if (diff === 1) return "Yesterday";
        if (diff < 7) return d.toLocaleDateString(Qt.locale(), "dddd");
        return d.toLocaleDateString(Qt.locale(), "MMM d");
    }

    // --- Pin / favorite ---------------------------------------------------
    // Pinned by content (the part after the cliphist id), so a pin survives
    // even when cliphist re-assigns ids on re-copy. Persisted to JSON.
    property var pins: []   // array of content keys, newest pin first
    function entryKey(entry) {
        return `${entry}`.split("\t").slice(1).join("\t");
    }
    function isPinned(entry) {
        return root.pins.includes(root.entryKey(entry));
    }
    function togglePin(entry) {
        const key = root.entryKey(entry);
        if (!key) return;
        const without = (root.pins ?? []).filter(k => k !== key);
        if (without.length === (root.pins ?? []).length)
            without.unshift(key);   // wasn't pinned -> pin it
        root.pins = without;
        pinsFileView.setText(JSON.stringify(root.pins));
    }
    // Pinned entries first (in pin order), then the rest in cliphist order.
    function withPinnedFirst(list) {
        const pinned = [], rest = [];
        for (const e of list) (root.isPinned(e) ? pinned : rest).push(e);
        pinned.sort((a, b) => root.pins.indexOf(root.entryKey(a)) - root.pins.indexOf(root.entryKey(b)));
        return pinned.concat(rest);
    }

    // --- Smart icon -------------------------------------------------------
    // A material symbol hinting at the entry's content type.
    function entryIcon(entry) {
        if (root.entryIsImage(entry)) return "image";
        const content = root.entryKey(entry).trim();
        if (/^https?:\/\//i.test(content)) return "link";
        if (/^#(?:[0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(content)) return "palette";
        if (/^(?:\/|~\/|\.\.?\/)\S*$/.test(content)) return "folder";
        if (/^[\w.+-]+@[\w-]+\.[\w.-]+$/.test(content)) return "mail";
        if (/^[+\-]?[\d.,\s]+$/.test(content) && /\d/.test(content)) return "tag";
        return "content_paste";
    }
    readonly property var preparedEntries: entries.map(a => ({
        name: Fuzzy.prepare(`${a.replace(/^\s*\S+\s+/, "")}`),
        entry: a
    }))
    function fuzzyQuery(search: string): var {
        if (search.trim() === "") {
            return entries;
        }
        if (root.sloppySearch) {
            const results = entries.slice(0, 100).map(str => ({
                entry: str,
                score: Levendist.computeTextMatchScore(str.toLowerCase(), search.toLowerCase())
            })).filter(item => item.score > root.scoreThreshold)
                .sort((a, b) => b.score - a.score)
            return results
                .map(item => item.entry)
        }

        return Fuzzy.go(search, preparedEntries, {
            all: true,
            key: "name"
        }).map(r => {
            return r.obj.entry
        });
    }

    function entryIsImage(entry) {
        return !!(/^\d+\t\[\[.*binary data.*\d+x\d+.*\]\]$/.test(entry))
    }

    function refresh() {
        readProc.buffer = []
        readProc.running = true
        timesFileView.reload()
    }

    function copy(entry) {
        if (root.cliphistBinary.includes("cliphist")) // Classic cliphist
            Quickshell.execDetached(["bash", "-c", `printf '${StringUtils.shellSingleQuoteEscape(entry)}' | ${root.cliphistBinary} decode | wl-copy`]);
        else { // Stash
            const entryNumber = entry.split("\t")[0];
            Quickshell.execDetached(["bash", "-c", `${root.cliphistBinary} decode ${entryNumber} | wl-copy`]);
        }
    }

    function paste(entry) {
        // Copy the entry, then (after the launcher closes and focus returns to
        // the app) press Ctrl+V via ydotool so it actually types into the app.
        if (root.cliphistBinary.includes("cliphist")) // Classic cliphist
            Quickshell.execDetached(["bash", "-c", `printf '${StringUtils.shellSingleQuoteEscape(entry)}' | ${root.cliphistBinary} decode | wl-copy && sleep 0.15 && ${root.pressPasteCommand}`]);
        else { // Stash
            const entryNumber = entry.split("\t")[0];
            Quickshell.execDetached(["bash", "-c", `${root.cliphistBinary} decode ${entryNumber} | wl-copy; sleep 0.15; ${root.pressPasteCommand}`]);
        }
    }

    function superpaste(count, isImage = false) {
        // Find entries
        const targetEntries = entries.filter(entry => {
            if (!isImage) return true;
            return entryIsImage(entry);
        }).slice(0, count)
        const pasteCommands = [...targetEntries].reverse().map(entry => `printf '${StringUtils.shellSingleQuoteEscape(entry)}' | ${root.cliphistBinary} decode | wl-copy && sleep ${root.pasteDelay} && ${root.pressPasteCommand}`)
        // Act
        Quickshell.execDetached(["bash", "-c", pasteCommands.join(` && sleep ${root.pasteDelay} && `)]);
    }

    Process {
        id: deleteProc
        property string entry: ""
        command: ["bash", "-c", `echo '${StringUtils.shellSingleQuoteEscape(deleteProc.entry)}' | ${root.cliphistBinary} delete`]
        function deleteEntry(entry) {
            deleteProc.entry = entry;
            deleteProc.running = true;
            deleteProc.entry = "";
        }
        onExited: (exitCode, exitStatus) => {
            root.refresh();
        }
    }

    function deleteEntry(entry) {
        deleteProc.deleteEntry(entry);
    }

    Process {
        id: wipeProc
        command: [root.cliphistBinary, "wipe"]
        onExited: (exitCode, exitStatus) => {
            root.refresh();
        }
    }

    function wipe() {
        wipeProc.running = true;
    }

    Connections {
        target: Quickshell
        function onClipboardTextChanged() {
            delayedUpdateTimer.restart()
        }
    }

    Timer {
        id: delayedUpdateTimer
        interval: Config.options.hacks.arbitraryRaceConditionDelay
        repeat: false
        onTriggered: {
            root.refresh()
        }
    }

    Process {
        id: readProc
        property list<string> buffer: []

        command: [root.cliphistBinary, "list"]

        stdout: SplitParser {
            onRead: (line) => {
                readProc.buffer.push(line)
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.entries = readProc.buffer
            } else {
                console.error("[Cliphist] Failed to refresh with code", exitCode, "and status", exitStatus)
            }
        }
    }

    IpcHandler {
        target: "cliphistService"

        function update(): void {
            root.refresh()
        }
    }

    FileView {
        id: timesFileView
        path: Qt.resolvedUrl(`${Directories.state}/user/cliphist_times.tsv`)
        onLoaded: {
            const map = {};
            const txt = timesFileView.text() ?? "";
            for (const line of txt.split("\n")) {
                const p = line.trim().split(/\s+/);
                if (p.length >= 2)
                    map[p[0]] = parseInt(p[1]);
            }
            root.times = map;
        }
        onLoadFailed: () => {
            root.times = ({});
        }
    }

    Component.onCompleted: pinsFileView.reload()

    FileView {
        id: pinsFileView
        path: Qt.resolvedUrl(`${Directories.state}/user/cliphist_pins.json`)
        onLoaded: {
            try {
                root.pins = JSON.parse(pinsFileView.text()) ?? [];
            } catch (e) {
                root.pins = [];
            }
        }
        onLoadFailed: error => {
            root.pins = [];
            if (error == FileViewError.FileNotFound)
                pinsFileView.setText(JSON.stringify(root.pins));
        }
    }
}
