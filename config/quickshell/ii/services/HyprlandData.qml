pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

/**
 * Provides access to some Hyprland data not available in Quickshell.Hyprland.
 */
Singleton {
    id: root
    property var windowList: []
    property var addresses: []
    property var windowByAddress: ({})
    property var workspaces: []
    property var workspaceIds: []
    property var workspaceById: ({})
    property var activeWorkspace: null
    property var monitors: []
    property var layers: ({})
    property var biggestWindowByWorkspace: ({})

    // Convenient stuff

    function toplevelsForWorkspace(workspace) {
        return ToplevelManager.toplevels.values.filter(toplevel => {
            const address = `0x${toplevel.HyprlandToplevel?.address}`;
            var win = HyprlandData.windowByAddress[address];
            return win?.workspace?.id === workspace;
        })
    }

    function hyprlandClientsForWorkspace(workspace) {
        return root.windowList.filter(win => win.workspace.id === workspace);
    }

    function clientForToplevel(toplevel) {
        if (!toplevel || !toplevel.HyprlandToplevel) {
            return null;
        }
        const address = `0x${toplevel?.HyprlandToplevel?.address}`;
        return root.windowByAddress[address];
    }

    // Internals

    function updateWindowList() {
        getClients.running = true;
    }

    function updateLayers() {
        getLayers.running = true;
    }

    function updateMonitors() {
        getMonitors.running = true;
    }

    function updateWorkspaces() {
        getWorkspaces.running = true;
        getActiveWorkspace.running = true;
    }

    function updateAll() {
        updateWindowList();
        updateMonitors();
        updateLayers();
        updateWorkspaces();
    }

    // Coalesce bursts of Hyprland events onto a single deferred refresh. Without this,
    // EVERY raw event — including windowtitlev2, which terminals fire continuously as
    // their title changes — spawned 5 hyprctl subprocesses + 5 main-thread JSON parses,
    // freezing the whole shell. We now debounce, and only refetch the categories an
    // event can actually affect.
    property bool _pendingWindows: false
    property bool _pendingWorkspaces: false
    property bool _pendingMonitors: false
    property bool _pendingLayers: false

    function scheduleUpdate(windows, workspaces, monitors, layers) {
        if (windows) root._pendingWindows = true;
        if (workspaces) root._pendingWorkspaces = true;
        if (monitors) root._pendingMonitors = true;
        if (layers) root._pendingLayers = true;
        updateDebounce.restart();
    }

    Timer {
        id: updateDebounce
        interval: 80
        repeat: false
        onTriggered: {
            if (root._pendingWindows) { root.updateWindowList(); root._pendingWindows = false; }
            if (root._pendingWorkspaces) { root.updateWorkspaces(); root._pendingWorkspaces = false; }
            if (root._pendingMonitors) { root.updateMonitors(); root._pendingMonitors = false; }
            if (root._pendingLayers) { root.updateLayers(); root._pendingLayers = false; }
        }
    }

    function biggestWindowForWorkspace(workspaceId) {
        const windowsInThisWorkspace = HyprlandData.windowList.filter(w => w.workspace.id == workspaceId);
        return windowsInThisWorkspace.reduce((maxWin, win) => {
            const maxArea = (maxWin?.size?.[0] ?? 0) * (maxWin?.size?.[1] ?? 0);
            const winArea = (win?.size?.[0] ?? 0) * (win?.size?.[1] ?? 0);
            return winArea > maxArea ? win : maxWin;
        }, null);
    }

    Component.onCompleted: {
        updateAll();
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            // console.log("Hyprland raw event:", event.name);
            const name = event.name;
            if (["openlayer", "closelayer", "screencast"].includes(name)) return;
            // Title / active-window changes are by far the most frequent events and only
            // affect the client list — never refetch monitors/layers/workspaces for them.
            if (name === "windowtitle" || name === "windowtitlev2"
                || name === "activewindow" || name === "activewindowv2") {
                root.scheduleUpdate(true, false, false, false);
                return;
            }
            // Workspace focus/lifecycle + monitor focus events do NOT change the client
            // list or layers — no window moves when you just switch/create/destroy/rename a
            // workspace. Refetching `hyprctl clients` (+ parsing it on the main thread) on
            // every workspace switch is what janked the bar's sliding pill animation: the
            // parse landed ~80ms later, right inside the pill's 300ms slide, and dropped
            // frames. Refresh only workspaces + monitors for these (cheap), never clients.
            if (name === "workspace" || name === "workspacev2"
                || name === "focusedmon" || name === "focusedmonv2"
                || name === "activespecial" || name === "activespecialv2"
                || name === "createworkspace" || name === "createworkspacev2"
                || name === "destroyworkspace" || name === "destroyworkspacev2"
                || name === "moveworkspace" || name === "moveworkspacev2"
                || name === "renameworkspace") {
                root.scheduleUpdate(false, true, true, false);
                return;
            }
            // Any other (structural) event that can move/add/remove windows (openwindow,
            // closewindow, movewindow, fullscreen, changefloatingmode, pin, …): refresh
            // everything, coalesced/debounced.
            root.scheduleUpdate(true, true, true, true);
        }
    }

    Process {
        id: getClients
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            id: clientsCollector
            onStreamFinished: {
                root.windowList = JSON.parse(clientsCollector.text)
                let tempWinByAddress = {};
                for (var i = 0; i < root.windowList.length; ++i) {
                    var win = root.windowList[i];
                    tempWinByAddress[win.address] = win;
                }
                root.windowByAddress = tempWinByAddress;
                root.addresses = root.windowList.map(win => win.address);
                // Precompute biggest window per workspace once here, instead of every
                // workspace button re-scanning the full list on each window change.
                let tempBiggest = {};
                for (var j = 0; j < root.windowList.length; ++j) {
                    const w = root.windowList[j];
                    const wsId = w?.workspace?.id;
                    if (wsId === undefined) continue;
                    const area = (w?.size?.[0] ?? 0) * (w?.size?.[1] ?? 0);
                    const cur = tempBiggest[wsId];
                    const curArea = (cur?.size?.[0] ?? 0) * (cur?.size?.[1] ?? 0);
                    if (!cur || area > curArea) tempBiggest[wsId] = w;
                }
                root.biggestWindowByWorkspace = tempBiggest;
            }
        }
    }

    Process {
        id: getMonitors
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            id: monitorsCollector
            onStreamFinished: {
                root.monitors = JSON.parse(monitorsCollector.text);
            }
        }
    }

    Process {
        id: getLayers
        command: ["hyprctl", "layers", "-j"]
        stdout: StdioCollector {
            id: layersCollector
            onStreamFinished: {
                root.layers = JSON.parse(layersCollector.text);
            }
        }
    }

    Process {
        id: getWorkspaces
        command: ["hyprctl", "workspaces", "-j"]
        stdout: StdioCollector {
            id: workspacesCollector
            onStreamFinished: {
                var rawWorkspaces = JSON.parse(workspacesCollector.text);
                // Filter out invalid workspace ids (e.g. lock-screen temp workspace 2147483647 - N)
                root.workspaces = rawWorkspaces.filter(ws => ws.id >= 1 && ws.id <= 100);
                let tempWorkspaceById = {};
                for (var i = 0; i < root.workspaces.length; ++i) {
                    var ws = root.workspaces[i];
                    tempWorkspaceById[ws.id] = ws;
                }
                root.workspaceById = tempWorkspaceById;
                root.workspaceIds = root.workspaces.map(ws => ws.id);
            }
        }
    }

    Process {
        id: getActiveWorkspace
        command: ["hyprctl", "activeworkspace", "-j"]
        stdout: StdioCollector {
            id: activeWorkspaceCollector
            onStreamFinished: {
                root.activeWorkspace = JSON.parse(activeWorkspaceCollector.text);
            }
        }
    }
}
