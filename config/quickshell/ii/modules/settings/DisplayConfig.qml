import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Quickshell
import Quickshell.Io

ContentPage {
    id: page
    forceWidth: true

    property var monitors: []
    property bool vrrOn: false

    function refresh() { monProc.running = true; vrrProc.running = true; }
    Component.onCompleted: refresh()

    Process { // live monitor list (includes HDMI/external when connected)
        id: monProc
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector { onStreamFinished: { try { page.monitors = JSON.parse(text); } catch (e) { page.monitors = []; } } }
    }
    Process {
        id: vrrProc
        command: ["hyprctl", "getoption", "misc:vrr", "-j"]
        stdout: StdioCollector { onStreamFinished: { try { page.vrrOn = (JSON.parse(text).int ?? 0) !== 0; } catch (e) {} } }
    }
    Timer { id: reapplyRead; interval: 600; onTriggered: page.refresh() }

    function applyMonitor(m, opts) {
        const mode = opts.mode ?? `${m.width}x${m.height}@${m.refreshRate.toFixed(2)}`;
        const scale = opts.scale ?? m.scale;
        const transform = opts.transform ?? m.transform;
        Quickshell.execDetached(["hyprctl", "eval",
            `hl.monitor({output="${m.name}", mode="${mode}", position="auto", scale=${scale}, transform=${transform}})`]);
        reapplyRead.restart();
    }
    function setVrr(on) {
        Quickshell.execDetached(["hyprctl", "eval", `hl.config({misc = {vrr = ${on ? 1 : 0}}})`]);
        page.vrrOn = on;
    }

    // Brightness (per connected screen)
    ContentSection {
        icon: "brightness_6"
        title: Translation.tr("Brightness")
        Repeater {
            model: Quickshell.screens
            delegate: RowLayout {
                required property var modelData
                readonly property var bm: Brightness.getMonitorForScreen(modelData)
                Layout.fillWidth: true
                spacing: 10
                visible: bm !== null
                MaterialSymbol { text: "brightness_low"; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnSurfaceVariant }
                StyledSlider {
                    Layout.fillWidth: true
                    from: 0.01; to: 1
                    value: parent.bm?.brightness ?? 1
                    onMoved: if (parent.bm) parent.bm.setBrightness(value)
                }
                StyledText {
                    Layout.minimumWidth: 38; horizontalAlignment: Text.AlignRight
                    color: Appearance.colors.colOnSurface
                    text: `${Math.round((parent.bm?.brightness ?? 0) * 100)}%`
                }
            }
        }
    }

    // Adaptive sync (global). VRR capability isn't reliably exposed (kernel
    // vrr_capable is often absent), so we gate on refresh rate: only offer the toggle
    // when a connected monitor runs above 60Hz, where VRR is actually meaningful.
    // (A plain 60Hz panel gets nothing from it and it can cause flicker.)
    readonly property bool anyHighRefresh: page.monitors.some(m => (m.refreshRate ?? 0) > 61)
    ContentSection {
        visible: page.anyHighRefresh
        icon: "monitor_heart"
        title: Translation.tr("Adaptive sync (VRR)")
        ConfigSwitch {
            buttonIcon: "sync"
            text: Translation.tr("Variable refresh rate")
            checked: page.vrrOn
            onCheckedChanged: if (checked !== page.vrrOn) page.setVrr(checked)
            StyledToolTip { text: Translation.tr("Matches refresh to content. On some laptop panels this can cause a 60Hz feel/flicker — turn off for constant max refresh.") }
        }
    }

    // Per-monitor controls
    Repeater {
        model: ScriptModel { values: page.monitors }
        delegate: ContentSection {
            required property var modelData
            readonly property var m: modelData
            icon: "desktop_windows"
            title: m.name + (m.model && m.model !== "" ? `  ·  ${m.model}` : "")

            // Resolution + refresh
            ContentSubsectionLabel { text: Translation.tr("Resolution & refresh") }
            ConfigSelectionArray {
                currentValue: `${m.width}x${m.height}@${m.refreshRate.toFixed(2)}`
                onSelected: newValue => page.applyMonitor(m, { mode: newValue })
                options: (m.availableModes ?? []).map(s => {
                    const clean = s.replace("Hz", "");
                    const at = clean.split("@");
                    const res = at[0], rate = at[1] ?? "60";
                    return {
                        displayName: `${res.replace("x", "×")}  ${Math.round(parseFloat(rate))}Hz`,
                        value: `${res}@${rate}`
                    };
                })
            }

            // Scale
            ContentSubsectionLabel { text: Translation.tr("Scale") }
            ConfigSelectionArray {
                currentValue: m.scale
                onSelected: newValue => page.applyMonitor(m, { scale: newValue })
                options: [
                    { displayName: "100%", value: 1.0 },
                    { displayName: "125%", value: 1.25 },
                    { displayName: "150%", value: 1.5 },
                    { displayName: "160%", value: 1.6 },
                    { displayName: "180%", value: 1.8 },
                    { displayName: "200%", value: 2.0 }
                ]
            }

            // Rotation / transform
            ContentSubsectionLabel { text: Translation.tr("Rotation") }
            ConfigSelectionArray {
                currentValue: m.transform
                onSelected: newValue => page.applyMonitor(m, { transform: newValue })
                options: [
                    { displayName: Translation.tr("Normal"), icon: "screen_rotation_up", value: 0 },
                    { displayName: "90°", icon: "screen_rotation", value: 1 },
                    { displayName: "180°", icon: "screen_rotation", value: 2 },
                    { displayName: "270°", icon: "screen_rotation", value: 3 }
                ]
            }

            StyledText {
                Layout.topMargin: 2
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                text: {
                    const parts = [`${m.width}×${m.height} @ ${m.refreshRate.toFixed(0)}Hz`, `scale ${m.scale}`];
                    if (m.make) parts.push(m.make);
                    return parts.join("  ·  ");
                }
            }
        }
    }
}
