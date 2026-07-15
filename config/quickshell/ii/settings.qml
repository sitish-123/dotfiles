//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

// Adjust this to make the app smaller or larger
//@ pragma Env QT_SCALE_FACTOR=1

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions as CF

ApplicationWindow {
    id: root
    property string firstRunFilePath: CF.FileUtils.trimFileProtocol(`${Directories.state}/user/first_run.txt`)
    property string firstRunFileContent: "This file is just here to confirm you've been greeted :>"
    property real contentPadding: 8
    property bool showNextTime: false
    property var pages: [
        // ── System: hardware & OS ───────────────────────────────────────────
        {
            section: Translation.tr("System"),
            name: Translation.tr("Network"),
            icon: "wifi",
            component: "modules/settings/NetworkConfig.qml"
        },
        {
            section: Translation.tr("System"),
            name: Translation.tr("Bluetooth"),
            icon: "bluetooth",
            component: "modules/settings/BluetoothConfig.qml"
        },
        {
            section: Translation.tr("System"),
            name: Translation.tr("Display"),
            icon: "brightness_6",
            component: "modules/settings/DisplayConfig.qml"
        },
        {
            section: Translation.tr("System"),
            name: Translation.tr("Sound"),
            icon: "volume_up",
            component: "modules/settings/SoundConfig.qml"
        },
        {
            section: Translation.tr("System"),
            name: Translation.tr("Power"),
            icon: "power_settings_new",
            component: "modules/settings/PowerConfig.qml"
        },
        {
            section: Translation.tr("System"),
            name: Translation.tr("Battery"),
            icon: "battery_full",
            component: "modules/settings/BatteryConfig.qml"
        },
        {
            section: Translation.tr("System"),
            name: Translation.tr("Updates"),
            icon: "system_update",
            component: "modules/settings/UpdatesConfig.qml"
        },
        // ── Appearance: how the desktop looks ───────────────────────────────
        {
            section: Translation.tr("Appearance"),
            name: Translation.tr("Personalization"),
            icon: "palette",
            component: "modules/settings/PersonalizationConfig.qml"
        },
        {
            section: Translation.tr("Appearance"),
            name: Translation.tr("Wallpaper"),
            icon: "wallpaper",
            component: "modules/settings/BackgroundConfig.qml"
        },
        {
            section: Translation.tr("Appearance"),
            name: Translation.tr("Bar"),
            icon: "toast",
            iconRotation: 180,
            component: "modules/settings/BarConfig.qml"
        },
        {
            section: Translation.tr("Appearance"),
            name: Translation.tr("Interface"),
            icon: "bottom_app_bar",
            component: "modules/settings/InterfaceConfig.qml"
        },
        // ── Window manager: Hyprland behavior ───────────────────────────────
        {
            section: Translation.tr("Window manager"),
            name: Translation.tr("Input & style"),
            icon: "tune",
            component: "modules/settings/WindowManagerConfig.qml"
        },
        {
            section: Translation.tr("Window manager"),
            name: Translation.tr("Overview"),
            icon: "grid_view",
            component: "modules/settings/HyprtaskingConfig.qml"
        },
        {
            section: Translation.tr("Window manager"),
            name: Translation.tr("Keybinds"),
            icon: "keyboard",
            component: "modules/settings/KeybindsConfig.qml"
        },
        // ── Startup: session env & autostart ────────────────────────────────
        {
            section: Translation.tr("Startup"),
            name: Translation.tr("Autostart"),
            icon: "rocket_launch",
            component: "modules/settings/AutostartConfig.qml"
        },
        {
            section: Translation.tr("Startup"),
            name: Translation.tr("Environment"),
            icon: "terminal",
            component: "modules/settings/EnvironmentConfig.qml"
        },
        // ── Shell: quickshell internals ─────────────────────────────────────
        {
            section: Translation.tr("Shell"),
            name: Translation.tr("General"),
            icon: "browse",
            component: "modules/settings/GeneralConfig.qml"
        },
        {
            section: Translation.tr("Shell"),
            name: Translation.tr("Services"),
            icon: "settings",
            component: "modules/settings/ServicesConfig.qml"
        },
        {
            section: Translation.tr("Shell"),
            name: Translation.tr("Advanced"),
            icon: "construction",
            component: "modules/settings/AdvancedConfig.qml"
        },
        // ── About ───────────────────────────────────────────────────────────
        {
            section: Translation.tr("About"),
            name: Translation.tr("About"),
            icon: "info",
            component: "modules/settings/About.qml"
        }
    ]
    property int currentPage: 0

    // Persistent-instance model: when launched with II_SETTINGS_HIDDEN=1 (login prewarm)
    // start hidden and stay alive so a later `ipc call settings show` opens instantly.
    // A direct launch (no env var) still shows immediately.
    visible: Quickshell.env("II_SETTINGS_HIDDEN") !== "1"
    // Closing (X button / window close) hides instead of quitting, keeping the
    // process warm for the next open.
    onClosing: (close) => {
        close.accepted = false;
        root.visible = false;
    }
    title: "illogical-impulse Settings"

    IpcHandler {
        target: "settings"

        function toggle(): void {
            root.visible = !root.visible;
            if (root.visible) {
                root.raise();
                root.requestActivate();
            }
        }

        function show(): void {
            root.visible = true;
            root.raise();
            root.requestActivate();
        }

        function hide(): void {
            root.visible = false;
        }
    }

    Component.onCompleted: {
        MaterialThemeLoader.reapplyTheme()
        Config.readWriteDelay = 0 // Settings app always only sets one var at a time so delay isn't needed
    }

    minimumWidth: 750
    minimumHeight: 500
    width: 1100
    height: 750
    color: Appearance.m3colors.m3background

    ColumnLayout {
        anchors {
            fill: parent
            margins: contentPadding
        }

        Keys.onPressed: (event) => {
            if (event.modifiers === Qt.ControlModifier) {
                if (event.key === Qt.Key_PageDown) {
                    root.currentPage = Math.min(root.currentPage + 1, root.pages.length - 1)
                    event.accepted = true;
                } 
                else if (event.key === Qt.Key_PageUp) {
                    root.currentPage = Math.max(root.currentPage - 1, 0)
                    event.accepted = true;
                }
                else if (event.key === Qt.Key_Tab) {
                    root.currentPage = (root.currentPage + 1) % root.pages.length;
                    event.accepted = true;
                }
                else if (event.key === Qt.Key_Backtab) {
                    root.currentPage = (root.currentPage - 1 + root.pages.length) % root.pages.length;
                    event.accepted = true;
                }
            }
        }

        Item { // Titlebar
            visible: Config.options?.windows.showTitlebar
            Layout.fillWidth: true
            Layout.fillHeight: false
            implicitHeight: Math.max(titleText.implicitHeight, windowControlsRow.implicitHeight)
            StyledText {
                id: titleText
                anchors {
                    left: Config.options.windows.centerTitle ? undefined : parent.left
                    horizontalCenter: Config.options.windows.centerTitle ? parent.horizontalCenter : undefined
                    verticalCenter: parent.verticalCenter
                    leftMargin: 12
                }
                color: Appearance.colors.colOnLayer0
                text: Translation.tr("Settings")
                font {
                    family: Appearance.font.family.title
                    pixelSize: Appearance.font.pixelSize.title
                    variableAxes: Appearance.font.variableAxes.title
                }
            }
            RowLayout { // Window controls row
                id: windowControlsRow
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                RippleButton {
                    buttonRadius: Appearance.rounding.full
                    implicitWidth: 35
                    implicitHeight: 35
                    onClicked: root.close()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: "close"
                        iconSize: 20
                    }
                }
            }
        }

        RowLayout { // Window content with navigation rail and content pane
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: contentPadding
            Item {
                id: navRailWrapper
                Layout.fillHeight: true
                Layout.margins: 5
                clip: true
                implicitWidth: navRail.expanded ? 235 : fab.baseSize
                Behavior on implicitWidth {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                NavigationRail { // Window content with navigation rail and content pane
                    id: navRail
                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                    }
                    spacing: 10
                    expanded: root.width > 900
                    
                    NavigationRailExpandButton {
                        focus: root.visible
                    }

                    FloatingActionButton {
                        id: fab
                        property bool justCopied: false
                        iconText: justCopied ? "check" : "edit"
                        buttonText: justCopied ? Translation.tr("Path copied") : Translation.tr("Config file")
                        expanded: navRail.expanded
                        downAction: () => {
                            Qt.openUrlExternally(`${Directories.config}/illogical-impulse/config.json`);
                        }
                        altAction: () => {
                            Quickshell.clipboardText = CF.FileUtils.trimFileProtocol(`${Directories.config}/illogical-impulse/config.json`);
                            fab.justCopied = true;
                            revertTextTimer.restart()
                        }

                        Timer {
                            id: revertTextTimer
                            interval: 1500
                            onTriggered: {
                                fab.justCopied = false;
                            }
                        }

                        StyledToolTip {
                            text: Translation.tr("Open the shell config file\nAlternatively right-click to copy path")
                        }
                    }

                    StyledFlickable { // Scrollable grouped tabs — the page list can exceed the rail height
                        id: navFlickable
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                        Layout.topMargin: 6
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: width
                        contentHeight: tabsColumn.implicitHeight

                        ColumnLayout { // Grouped tabs (System / Customization) with section labels
                            id: tabsColumn
                            width: navFlickable.width
                            spacing: 0
                            Repeater {
                                model: root.pages
                                delegate: ColumnLayout {
                                    required property var index
                                    required property var modelData
                                    readonly property bool sectionStart: index === 0 || root.pages[index - 1].section !== modelData.section
                                    Layout.fillWidth: true
                                    Layout.topMargin: (index > 0 && sectionStart) ? 6 : 0
                                    spacing: 0

                                    StyledText {
                                        visible: navRail.expanded && parent.sectionStart
                                        Layout.leftMargin: 10
                                        Layout.bottomMargin: 2
                                        Layout.topMargin: 2
                                        text: modelData.section ?? ""
                                        color: Appearance.colors.colSubtext
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        font.weight: Font.Medium
                                    }
                                    NavigationRailButton {
                                        Layout.fillWidth: true
                                        toggled: root.currentPage === parent.index
                                        onPressed: root.currentPage = parent.index
                                        expanded: navRail.expanded
                                        buttonIcon: modelData.icon
                                        buttonIconRotation: modelData.iconRotation || 0
                                        buttonText: modelData.name
                                        showToggledHighlight: true
                                        baseSize: 44
                                        baseHighlightHeight: 28
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Rectangle { // Content container
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Appearance.m3colors.m3surfaceContainerLow
                radius: Appearance.rounding.windowRounding - root.contentPadding

                Loader {
                    id: pageLoader
                    anchors.fill: parent
                    opacity: 1.0

                    active: Config.ready
                    Component.onCompleted: {
                        source = root.pages[0].component
                    }

                    // Error boundary: a page that fails to load (bad import / creation
                    // error) would otherwise blank the whole content pane silently. Show
                    // a placeholder instead; the next navigation resets `source`.
                    onStatusChanged: if (status === Loader.Error) pageLoader.sourceComponent = pageErrorComponent

                    Component {
                        id: pageErrorComponent
                        Item {
                            Text {
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                color: "#ff6b6b"
                                font.pixelSize: 16
                                text: "This settings page failed to load.\nSee the terminal/journal (qs) for the QML error."
                            }
                        }
                    }

                    Connections {
                        target: root
                        function onCurrentPageChanged() {
                            switchAnim.complete();
                            switchAnim.start();
                        }
                    }

                    SequentialAnimation {
                        id: switchAnim

                        NumberAnimation {
                            target: pageLoader
                            properties: "opacity"
                            from: 1
                            to: 0
                            duration: 100
                            easing.type: Appearance.animation.elementMoveExit.type
                            easing.bezierCurve: Appearance.animationCurves.emphasizedFirstHalf
                        }
                        ParallelAnimation {
                            PropertyAction {
                                target: pageLoader
                                property: "source"
                                value: root.pages[root.currentPage].component
                            }
                            PropertyAction {
                                target: pageLoader
                                property: "anchors.topMargin"
                                value: 20
                            }
                        }
                        ParallelAnimation {
                            NumberAnimation {
                                target: pageLoader
                                properties: "opacity"
                                from: 0
                                to: 1
                                duration: 200
                                easing.type: Appearance.animation.elementMoveEnter.type
                                easing.bezierCurve: Appearance.animationCurves.emphasizedLastHalf
                            }
                            NumberAnimation {
                                target: pageLoader
                                properties: "anchors.topMargin"
                                to: 0
                                duration: 200
                                easing.type: Appearance.animation.elementMoveEnter.type
                                easing.bezierCurve: Appearance.animationCurves.emphasizedLastHalf
                            }
                        }
                    }
                }
            }
        }
    }
}
