pragma Singleton
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Wayland

/**
 * A nice wrapper for date and time strings.
 */
Singleton {
    id: root

    property alias inhibit: idleInhibitor.enabled
    inhibit: false

    Connections {
        target: Persistent
        function onReadyChanged() {
            if (!Persistent.isNewHyprlandInstance) {
                root.inhibit = Persistent.states.idle.inhibit;
            } else {
                Persistent.states.idle.inhibit = root.inhibit;
            }
        }
    }

    function toggleInhibit(active = null) {
        if (active !== null) {
            root.inhibit = active;
        } else {
            root.inhibit = !root.inhibit;
        }
        Persistent.states.idle.inhibit = root.inhibit;
    }

    IdleInhibitor {
        id: idleInhibitor
        // Hyprland only honors the idle-inhibit protocol for a *mapped* surface. The old
        // 0×0 window often never mapped, so "Keep awake" silently did nothing and the
        // 5-min lock / 15-min suspend still fired — locking you out. Use a real 1×1,
        // transparent, click-through surface on the background layer: invisible and inert,
        // but reliably mapped, and never able to sit above hyprlock or steal input.
        window: PanelWindow {
            visible: true
            implicitWidth: 1
            implicitHeight: 1
            exclusiveZone: 0
            color: "transparent"
            WlrLayershell.namespace: "quickshell:idleInhibitor"
            WlrLayershell.layer: WlrLayer.Background
            anchors {
                top: true
                left: true
            }
            // Never interactable — can't grab pointer/keyboard (e.g. from the lockscreen)
            mask: Region {
                item: null
            }
        }
    }
}
