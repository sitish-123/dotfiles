pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import Quickshell
import Quickshell.Io
import QtQuick

/**
 * Recently-used emojis, most-recent-first, persisted to a JSON file.
 * Used by the emoji launcher to show recents and order by last used.
 */
Singleton {
    id: root
    property string filePath: `${Directories.state}/user/emoji_history.json`
    property var list: []        // array of emoji characters, most recent first
    readonly property int maxItems: 64

    function record(emoji) {
        if (!emoji || emoji.length === 0)
            return;
        const without = (root.list ?? []).filter(e => e !== emoji);
        without.unshift(emoji);
        root.list = without.slice(0, root.maxItems);
        historyFileView.setText(JSON.stringify(root.list));
    }

    Component.onCompleted: historyFileView.reload()

    FileView {
        id: historyFileView
        path: Qt.resolvedUrl(root.filePath)
        onLoaded: {
            try {
                root.list = JSON.parse(historyFileView.text()) ?? [];
            } catch (e) {
                root.list = [];
            }
        }
        onLoadFailed: error => {
            root.list = [];
            if (error == FileViewError.FileNotFound)
                historyFileView.setText(JSON.stringify(root.list));
        }
    }
}
