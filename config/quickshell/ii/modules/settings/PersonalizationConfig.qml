import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ContentPage {
    id: page
    forceWidth: true

    // Which surface the wallpaper picker / widget toggles target: 0 = Home (desktop), 1 = Lock screen
    property int wallpaperTarget: 0
    property int widgetTarget: 0

    property string hlTextColor: ""
    property string hlFont: ""
    property string hlFontClock: ""
    property string hlBgImage: ""

    Process {
        id: readColorsProc
        command: ["cat", FileUtils.trimFileProtocol(`${Directories.config}/hypr/hyprlock/colors.conf`)]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.split("\n")) {
                    const m = line.match(/^\$(\w+)\s*=\s*(.+)$/)
                    if (!m) continue
                    const [, key, val] = m
                    const v = val.trim()
                    if      (key === "text_color")          page.hlTextColor = v
                    else if (key === "font_family")         page.hlFont = v
                    else if (key === "font_family_clock")   page.hlFontClock = v
                    else if (key === "background_image")    page.hlBgImage = v
                }
            }
        }
    }

    Process { id: writeColorsProc }
    Process { id: writeHyprlockProc }

    function saveColorsConf() {
        const script = [
            "import sys, re, os",
            "path = os.path.expanduser(sys.argv[1])",
            "updates = dict(x.split('=', 1) for x in sys.argv[2].split('|'))",
            "try:",
            "    lines = open(path).readlines()",
            "except:",
            "    lines = []",
            "out = []",
            "for line in lines:",
            "    m = re.match(r'^\\$(\\w+)\\s*=', line)",
            "    if m and m.group(1) in updates:",
            "        out.append('$' + m.group(1) + ' = ' + updates[m.group(1)].strip() + '\\n')",
            "    else:",
            "        out.append(line)",
            "open(path, 'w').writelines(out)",
        ].join("\n")
        const updates = [
            "text_color=" + page.hlTextColor,
            "font_family=" + page.hlFont,
            "font_family_clock=" + page.hlFontClock,
            "background_image=" + page.hlBgImage,
        ].join("|")
        writeColorsProc.command = ["python3", "-c", script,
            "~/.config/hypr/hyprlock/colors.conf", updates]
        writeColorsProc.running = true
    }

    function saveHyprlockBg(path) {
        const script = [
            "import sys, re, os",
            "conf = os.path.expanduser(sys.argv[1])",
            "bg = sys.argv[2]",
            "try:",
            "    lines = open(conf).readlines()",
            "except:",
            "    lines = []",
            "out = []",
            "found = False",
            "for line in lines:",
            "    m = re.match(r'^(\\s*path\\s*=\\s*).*', line)",
            "    if m:",
            "        out.append(m.group(1) + bg + '\\n')",
            "        found = True",
            "    else:",
            "        out.append(line)",
            "if not found:",
            "    out.append('    path = ' + bg + '\\n')",
            "open(conf, 'w').writelines(out)",
        ].join("\n")
        writeHyprlockProc.command = ["python3", "-c", script,
            "~/.config/hypr/hyprlock.conf", path]
        writeHyprlockProc.running = true
    }

    Component.onCompleted: readColorsProc.running = true

    Process {
        id: lockBgPickerProc
        command: ["bash", "-c", "zenity --file-selection --title='Choose wallpaper' --file-filter='Images | *.jpg *.jpeg *.png *.webp' 2>/dev/null || kdialog --title 'Choose wallpaper' --getopenfilename \"$HOME\" '*.jpg *.jpeg *.png *.webp'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim()
                if (path.length > 0) {
                    Config.options.background.wallpaperPathLock = path
                    page.hlBgImage = path
                    page.saveColorsConf()
                    page.saveHyprlockBg(path)
                }
            }
        }
    }

    Process {
        id: homeBgPickerProc
        command: ["bash", "-c", "zenity --file-selection --title='Choose wallpaper' --file-filter='Images | *.jpg *.jpeg *.png *.webp' 2>/dev/null || kdialog --title 'Choose wallpaper' --getopenfilename \"$HOME\" '*.jpg *.jpeg *.png *.webp'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim()
                if (path.length > 0) {
                    Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --image "${path}"`])
                }
            }
        }
    }

    Process {
        id: randomWallProc
        property string status: ""
        property string scriptPath: `${Directories.scriptPath}/colors/random/random_konachan_wall.sh`
        command: ["bash", "-c", FileUtils.trimFileProtocol(randomWallProc.scriptPath)]
        stdout: SplitParser {
            onRead: data => { randomWallProc.status = data.trim() }
        }
    }

    function applyAccent(raw) {
        Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --color ${raw} --noswitch`])
    }
    function clearAccent() {
        Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --color clear --noswitch`])
    }

    component SmallLightDarkPreferenceButton: RippleButton {
        id: smallLightDarkPreferenceButton
        required property bool dark
        property color colText: toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
        padding: 12
        Layout.fillWidth: true
        Layout.minimumHeight: 80
        toggled: Appearance.m3colors.darkmode === dark
        colBackground: Appearance.colors.colLayer2
        onClicked: {
            Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --mode ${dark ? "dark" : "light"} --noswitch`])
        }
        contentItem: Item {
            anchors.centerIn: parent
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 4
                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    iconSize: 32
                    text: dark ? "dark_mode" : "light_mode"
                    color: smallLightDarkPreferenceButton.colText
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: dark ? Translation.tr("Dark") : Translation.tr("Light")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: smallLightDarkPreferenceButton.colText
                }
            }
        }
    }

    // ── Wallpaper & Colors ────────────────────────────────────────────────────
    ContentSection {
        icon: "format_paint"
        title: Translation.tr("Wallpaper & Colors")
        Layout.fillWidth: true

        ConfigSelectionArray {
            currentValue: page.wallpaperTarget
            onSelected: newValue => { page.wallpaperTarget = newValue }
            options: [
                { displayName: Translation.tr("Home"), icon: "wallpaper", value: 0 },
                { displayName: Translation.tr("Lock"),  icon: "lock",      value: 1 },
            ]
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Item {
                id: wallpaperPreviewBox
                implicitWidth: 300
                implicitHeight: 175
                readonly property bool home: page.wallpaperTarget === 0
                readonly property string lockPath: Config.options.background.wallpaperPathLock
                readonly property string previewSource: home
                    ? Config.options.background.wallpaperPath
                    : (lockPath.length > 0 ? lockPath : Config.options.background.wallpaperPath)

                StyledImage {
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    source: wallpaperPreviewBox.previewSource
                    cache: false
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: wallpaperPreviewBox.width
                            height: wallpaperPreviewBox.height
                            radius: Appearance.rounding.normal
                        }
                    }
                }

                Rectangle {
                    visible: !wallpaperPreviewBox.home && wallpaperPreviewBox.lockPath.length === 0
                    anchors { left: parent.left; bottom: parent.bottom; margins: 8 }
                    radius: Appearance.rounding.small
                    color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.25)
                    implicitWidth: badgeText.implicitWidth + 16
                    implicitHeight: badgeText.implicitHeight + 8
                    StyledText {
                        id: badgeText
                        anchors.centerIn: parent
                        text: Translation.tr("Same as desktop")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer0
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                RippleButtonWithIcon {
                    enabled: !randomWallProc.running
                    visible: wallpaperPreviewBox.home && Config.options.policies.weeb === 1
                    Layout.fillWidth: true
                    buttonRadius: Appearance.rounding.small
                    materialIcon: "ifl"
                    mainText: randomWallProc.running ? Translation.tr("Be patient...") : Translation.tr("Random: Konachan")
                    onClicked: {
                        randomWallProc.scriptPath = `${Directories.scriptPath}/colors/random/random_konachan_wall.sh`
                        randomWallProc.running = true
                    }
                    StyledToolTip { text: Translation.tr("Random SFW Anime wallpaper from Konachan\nImage is saved to ~/Pictures/Wallpapers") }
                }
                RippleButtonWithIcon {
                    enabled: !randomWallProc.running
                    visible: wallpaperPreviewBox.home && Config.options.policies.weeb === 1
                    Layout.fillWidth: true
                    buttonRadius: Appearance.rounding.small
                    materialIcon: "ifl"
                    mainText: randomWallProc.running ? Translation.tr("Be patient...") : Translation.tr("Random: osu! seasonal")
                    onClicked: {
                        randomWallProc.scriptPath = `${Directories.scriptPath}/colors/random/random_osu_wall.sh`
                        randomWallProc.running = true
                    }
                    StyledToolTip { text: Translation.tr("Random osu! seasonal background\nImage is saved to ~/Pictures/Wallpapers") }
                }
                RippleButtonWithIcon {
                    visible: wallpaperPreviewBox.home
                    Layout.fillWidth: true
                    buttonRadius: Appearance.rounding.small
                    materialIcon: "wallpaper"
                    onClicked: { homeBgPickerProc.running = true }
                    StyledToolTip { text: Translation.tr("Pick wallpaper image on your system") }
                    mainContentComponent: Component {
                        RowLayout {
                            spacing: 10
                            StyledText {
                                font.pixelSize: Appearance.font.pixelSize.small
                                text: Translation.tr("Choose file")
                                color: Appearance.colors.colOnSecondaryContainer
                            }
                            RowLayout {
                                spacing: 3
                                KeyboardKey { key: "Ctrl" }
                                KeyboardKey { key: Config.options.cheatsheet.superKey ?? "󰖳" }
                                StyledText { Layout.alignment: Qt.AlignVCenter; text: "+" }
                                KeyboardKey { key: "T" }
                            }
                        }
                    }
                }

                RippleButtonWithIcon {
                    visible: !wallpaperPreviewBox.home
                    Layout.fillWidth: true
                    buttonRadius: Appearance.rounding.small
                    materialIcon: "wallpaper"
                    mainText: Translation.tr("Choose file")
                    onClicked: { lockBgPickerProc.running = true }
                }
                RippleButtonWithIcon {
                    visible: !wallpaperPreviewBox.home
                    enabled: Config.options.background.wallpaperPathLock.length > 0
                    Layout.fillWidth: true
                    buttonRadius: Appearance.rounding.small
                    materialIcon: "image_search"
                    mainText: Translation.tr("Same as desktop")
                    onClicked: {
                        Config.options.background.wallpaperPathLock = ""
                        page.hlBgImage = Config.options.background.wallpaperPath
                        page.saveColorsConf()
                        page.saveHyprlockBg(Config.options.background.wallpaperPath)
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: page.wallpaperTarget === 1
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            wrapMode: Text.WordWrap
            text: Translation.tr("Shown on the lock screen (blurred if blur is on). Leave as \"Same as desktop\" to mirror your wallpaper.")
        }

        ContentSubsection {
            title: Translation.tr("Color scheme")
            ConfigSelectionArray {
                currentValue: Config.options.appearance.palette.type
                onSelected: newValue => {
                    Config.options.appearance.palette.type = newValue
                    Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --noswitch`])
                }
                options: [
                    { value: "auto",                displayName: Translation.tr("Auto") },
                    { value: "scheme-content",      displayName: Translation.tr("Content") },
                    { value: "scheme-expressive",   displayName: Translation.tr("Expressive") },
                    { value: "scheme-fidelity",     displayName: Translation.tr("Fidelity") },
                    { value: "scheme-fruit-salad",  displayName: Translation.tr("Fruit Salad") },
                    { value: "scheme-monochrome",   displayName: Translation.tr("Monochrome") },
                    { value: "scheme-neutral",      displayName: Translation.tr("Neutral") },
                    { value: "scheme-rainbow",      displayName: Translation.tr("Rainbow") },
                    { value: "scheme-tonal-spot",   displayName: Translation.tr("Tonal Spot") },
                ]
            }
        }

        ContentSubsection {
            title: Translation.tr("Accent color")
            spacing: 10

            Flow {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: ["#E53935","#E91E63","#FF6D00","#F9A825",
                            "#7CB342","#43A047","#00897B","#00ACC1",
                            "#1E88E5","#3949AB","#5E35B1","#8E24AA",
                            "#795548","#607D8B","#F06292","#80CBC4"]
                    delegate: Rectangle {
                        required property string modelData
                        property string hex: modelData
                        readonly property bool selected: (Config.options.appearance.palette.accentColor ?? "").replace(/^#/, "").toLowerCase() === hex.replace(/^#/, "").toLowerCase()
                        implicitWidth: 30; implicitHeight: 30
                        radius: Appearance.rounding.full
                        color: hex
                        border.width: selected ? 3 : 0
                        border.color: Appearance.colors.colOnLayer1
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                accentHexInput.text = parent.hex
                                page.applyAccent(parent.hex.replace(/^#/, ""))
                            }
                        }
                    }
                }
            }

            Item {
                id: hueSlider
                Layout.fillWidth: true
                implicitHeight: 24
                property real huePos: 0.0
                function pick(px) {
                    huePos = Math.max(0, Math.min(1, px / width))
                    const c = Qt.hsva(huePos, 0.75, 0.9, 1.0)
                    const h = v => Math.round(v * 255).toString(16).padStart(2, "0")
                    const raw = h(c.r) + h(c.g) + h(c.b)
                    accentHexInput.text = "#" + raw
                    page.applyAccent(raw)
                }

                Rectangle {
                    id: hueTrack
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 12
                    radius: height / 2
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.00; color: "#FF0000" }
                        GradientStop { position: 0.17; color: "#FFFF00" }
                        GradientStop { position: 0.33; color: "#00FF00" }
                        GradientStop { position: 0.50; color: "#00FFFF" }
                        GradientStop { position: 0.67; color: "#0000FF" }
                        GradientStop { position: 0.83; color: "#FF00FF" }
                        GradientStop { position: 1.00; color: "#FF0000" }
                    }
                }

                Rectangle {
                    id: hueThumb
                    width: 22; height: 22; radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    x: hueSlider.huePos * (hueSlider.width - width)
                    color: Qt.hsva(hueSlider.huePos, 0.75, 0.9, 1.0)
                    border.width: 3
                    border.color: Appearance.colors.colOnLayer0
                    Behavior on x { NumberAnimation { duration: 80 } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onPressed: e => hueSlider.pick(e.x)
                    onPositionChanged: e => { if (pressed) hueSlider.pick(e.x) }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    implicitWidth: 30; implicitHeight: 30
                    radius: Appearance.rounding.full
                    border.width: 1
                    border.color: Appearance.colors.colOutlineVariant
                    property string cleanHex: (Config.options.appearance.palette.accentColor ?? "").replace(/^#/, "")
                    color: /^[0-9A-Fa-f]{6}$/.test(cleanHex) ? Qt.color("#" + cleanHex) : Appearance.colors.colPrimary
                }
                MaterialTextArea {
                    id: accentHexInput
                    Layout.fillWidth: true
                    placeholderText: Config.options.appearance.palette.accentColor
                        ? "" : Translation.tr("From wallpaper — type a hex like #a1b2c3")
                    text: Config.options.appearance.palette.accentColor
                        ? ("#" + (Config.options.appearance.palette.accentColor ?? "").replace(/^#/, "")) : ""
                    onEditingFinished: {
                        const raw = text.trim().replace(/^#/, "")
                        if (/^[A-Fa-f0-9]{6}$/.test(raw)) page.applyAccent(raw)
                        else if (raw === "") page.clearAccent()
                    }
                }
                RippleButton {
                    implicitWidth: 38; implicitHeight: 38
                    buttonRadius: Appearance.rounding.full
                    enabled: !!Config.options.appearance.palette.accentColor
                    opacity: enabled ? 1 : 0.4
                    downAction: () => {
                        accentHexInput.text = ""
                        page.clearAccent()
                    }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "format_color_reset"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnSurface
                    }
                    StyledToolTip { text: Translation.tr("Reset to wallpaper-based theme") }
                }
            }
        }

        ConfigSwitch {
            buttonIcon: "ev_shadow"
            text: Translation.tr("Transparency")
            checked: Config.options.appearance.transparency.enable
            onCheckedChanged: { Config.options.appearance.transparency.enable = checked }
        }
    }

    // ── Light / Dark mode ─────────────────────────────────────────────────────
    ContentSection {
        icon: "dark_mode"
        title: Translation.tr("Appearance mode")
        Layout.fillWidth: true

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            uniformCellSizes: true
            SmallLightDarkPreferenceButton { dark: false; Layout.fillHeight: true }
            SmallLightDarkPreferenceButton { dark: true; Layout.fillHeight: true }
        }
    }

    // ── Bar & screen ──────────────────────────────────────────────────────────
    ContentSection {
        icon: "screenshot_monitor"
        title: Translation.tr("Bar & screen")

        ConfigRow {
            ContentSubsection {
                title: Translation.tr("Bar position")
                ConfigSelectionArray {
                    currentValue: (Config.options.bar.bottom ? 1 : 0) | (Config.options.bar.vertical ? 2 : 0)
                    onSelected: newValue => {
                        Config.options.bar.bottom = (newValue & 1) !== 0
                        Config.options.bar.vertical = (newValue & 2) !== 0
                    }
                    options: [
                        { displayName: Translation.tr("Top"),    icon: "arrow_upward",   value: 0 },
                        { displayName: Translation.tr("Left"),   icon: "arrow_back",     value: 2 },
                        { displayName: Translation.tr("Bottom"), icon: "arrow_downward", value: 1 },
                        { displayName: Translation.tr("Right"),  icon: "arrow_forward",  value: 3 },
                    ]
                }
            }
            ContentSubsection {
                title: Translation.tr("Bar style")
                ConfigSelectionArray {
                    currentValue: Config.options.bar.cornerStyle
                    onSelected: newValue => { Config.options.bar.cornerStyle = newValue }
                    options: [
                        { displayName: Translation.tr("Hug"),   icon: "line_curve",  value: 0 },
                        { displayName: Translation.tr("Float"), icon: "page_header", value: 1 },
                        { displayName: Translation.tr("Rect"),  icon: "toolbar",     value: 2 },
                    ]
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Screen round corner")
            ConfigSelectionArray {
                currentValue: Config.options.appearance.fakeScreenRounding
                onSelected: newValue => { Config.options.appearance.fakeScreenRounding = newValue }
                options: [
                    { displayName: Translation.tr("No"),                   icon: "close",           value: 0 },
                    { displayName: Translation.tr("Yes"),                  icon: "check",           value: 1 },
                    { displayName: Translation.tr("When not fullscreen"),  icon: "fullscreen_exit", value: 2 },
                ]
            }
        }
    }

    // ── Widgets ───────────────────────────────────────────────────────────────
    ContentSection {
        icon: "widgets"
        title: Translation.tr("Widgets")

        ConfigSelectionArray {
            currentValue: page.widgetTarget
            onSelected: newValue => { page.widgetTarget = newValue }
            options: [
                { displayName: Translation.tr("Home"), icon: "wallpaper", value: 0 },
                { displayName: Translation.tr("Lock"),  icon: "lock",      value: 1 },
            ]
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            visible: page.widgetTarget === 0

            ConfigSwitch {
                buttonIcon: "schedule"
                text: Translation.tr("Clock widget")
                checked: Config.options.background.widgets.clock.enable
                onCheckedChanged: { Config.options.background.widgets.clock.enable = checked }
                StyledToolTip { text: Translation.tr("Configure style in Background settings") }
            }
            ConfigSwitch {
                buttonIcon: "partly_cloudy_day"
                text: Translation.tr("Weather widget")
                checked: Config.options.background.widgets.weather.enable
                onCheckedChanged: { Config.options.background.widgets.weather.enable = checked }
                StyledToolTip { text: Translation.tr("Configure in Background settings") }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            visible: page.widgetTarget === 1

            ConfigSwitch {
                buttonIcon: "schedule"
                text: Translation.tr("Clock widget")
                checked: Config.options.lock.widgets.clock
                onCheckedChanged: { Config.options.lock.widgets.clock = checked }
            }
            ConfigSwitch {
                buttonIcon: "lock_clock"
                text: Translation.tr("Center clock")
                enabled: Config.options.lock.widgets.clock
                checked: Config.options.lock.centerClock
                onCheckedChanged: { Config.options.lock.centerClock = checked }
            }
            ConfigSwitch {
                buttonIcon: "partly_cloudy_day"
                text: Translation.tr("Weather widget")
                checked: Config.options.lock.widgets.weather
                onCheckedChanged: { Config.options.lock.widgets.weather = checked }
            }
        }
    }

    // ── Lock screen ───────────────────────────────────────────────────────────
    ContentSection {
        icon: "lock"
        title: Translation.tr("Lock screen")

        ConfigSwitch {
            buttonIcon: "blur_on"
            text: Translation.tr("Blur background")
            checked: Config.options.lock.blur.enable
            onCheckedChanged: { Config.options.lock.blur.enable = checked }
        }
        ConfigSwitch {
            buttonIcon: "label"
            text: Translation.tr("Show 'Locked' text")
            checked: Config.options.lock.showLockedText
            onCheckedChanged: { Config.options.lock.showLockedText = checked }
        }

        ContentSubsection {
            title: Translation.tr("Font")
            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("e.g. Google Sans Flex Medium")
                text: page.hlFont
                onEditingFinished: {
                    page.hlFont = text.trim()
                    page.hlFontClock = text.trim()
                    page.saveColorsConf()
                }
            }
        }
    }

    NoticeBox {
        Layout.fillWidth: true
        text: Translation.tr('Not all options are available in this app. You should also check the config file by hitting the "Config file" button on the topleft corner or opening %1 manually.').arg(Directories.shellConfigPath)

        Item { Layout.fillWidth: true }
        RippleButtonWithIcon {
            id: copyPathButton
            property bool justCopied: false
            Layout.fillWidth: false
            buttonRadius: Appearance.rounding.small
            materialIcon: justCopied ? "check" : "content_copy"
            mainText: justCopied ? Translation.tr("Path copied") : Translation.tr("Copy path")
            onClicked: {
                copyPathButton.justCopied = true
                Quickshell.clipboardText = FileUtils.trimFileProtocol(`${Directories.config}/illogical-impulse/config.json`)
                revertTextTimer.restart()
            }
            colBackground: ColorUtils.transparentize(Appearance.colors.colPrimaryContainer)
            colBackgroundHover: Appearance.colors.colPrimaryContainerHover
            colRipple: Appearance.colors.colPrimaryContainerActive

            Timer {
                id: revertTextTimer
                interval: 1500
                onTriggered: { copyPathButton.justCopied = false }
            }
        }
    }
}
