pragma Singleton

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Wayland

Singleton {
    id: root

    function isPinned(appId) {
        return Config.options.dock.pinnedApps.indexOf(appId) !== -1;
    }

    function togglePin(appId) {
        if (root.isPinned(appId)) {
            Config.options.dock.pinnedApps = Config.options.dock.pinnedApps.filter(id => id !== appId)
        } else {
            Config.options.dock.pinnedApps = Config.options.dock.pinnedApps.concat([appId])
        }
    }

    // Persistent cache of entry objects keyed by appId. Entries are reused across
    // recomputes so their identities (and the QObjects backing them) stay stable.
    // Recreating them every time and parenting to null made them JS-owned and
    // garbage-collectible, so the QML GC could free an entry that ScriptModel's
    // QQmlDelegateModel still referenced mid row-move, crashing quickshell
    // (ScriptModel::updateValuesUnique -> QAbstractItemModel::endMoveRows ->
    // QQmlDelegateModel::_q_itemsMoved -> SIGSEGV).
    property var _entryCache: ({})

    property list<var> apps: {
        var map = new Map();

        // Pinned apps
        const pinnedApps = Config.options?.dock.pinnedApps ?? [];
        for (const appId of pinnedApps) {
            if (!map.has(appId.toLowerCase())) map.set(appId.toLowerCase(), ({
                pinned: true,
                toplevels: []
            }));
        }

        // Separator
        if (pinnedApps.length > 0) {
            map.set("SEPARATOR", { pinned: false, toplevels: [] });
        }

        // Ignored apps
        const ignoredRegexStrings = Config.options?.dock.ignoredAppRegexes ?? [];
        const ignoredRegexes = ignoredRegexStrings.map(pattern => new RegExp(pattern, "i"));
        // Open windows
        for (const toplevel of ToplevelManager.toplevels.values) {
            if (ignoredRegexes.some(re => re.test(toplevel.appId))) continue;
            if (!map.has(toplevel.appId.toLowerCase())) map.set(toplevel.appId.toLowerCase(), ({
                pinned: false,
                toplevels: []
            }));
            map.get(toplevel.appId.toLowerCase()).toplevels.push(toplevel);
        }

        var values = [];
        var cache = root._entryCache;
        var seen = ({});

        for (const [key, value] of map) {
            var entry = cache[key];
            if (entry) {
                // Reuse the existing object, update it in place.
                entry.toplevels = value.toplevels;
                entry.pinned = value.pinned;
            } else {
                // Parent to root so the object is C++-owned, not GC-eligible.
                entry = appEntryComp.createObject(root, { appId: key, toplevels: value.toplevels, pinned: value.pinned });
                cache[key] = entry;
            }
            seen[key] = true;
            values.push(entry);
        }

        // Drop entries that no longer exist. destroy() is deferred, so the object
        // stays valid through this model update and is freed only once nothing
        // references it.
        for (const key in cache) {
            if (!seen[key]) {
                cache[key].destroy();
                delete cache[key];
            }
        }

        return values;
    }

    component TaskbarAppEntry: QtObject {
        id: wrapper
        required property string appId
        required property list<var> toplevels
        required property bool pinned
    }
    Component {
        id: appEntryComp
        TaskbarAppEntry {}
    }
}
