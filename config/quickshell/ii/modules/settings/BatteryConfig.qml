import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: root
    forceWidth: true

    property var procModel: []
    Process {
        id: procTop
        command: ["bash", "-c",
            "ps -eo comm,%cpu,%mem --sort=-%cpu --no-headers | head -n 30"]
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = text.trim().split("\n")
                    .filter(l => l.trim().length > 0)
                    .map(l => {
                        const p = l.trim().split(/\s+/)
                        const mem = parseFloat(p.pop()) || 0
                        const cpu = parseFloat(p.pop()) || 0
                        return { name: p.join(" "), cpu, mem }
                    })
                const agg = {}
                for (const p of raw) {
                    if (!agg[p.name]) agg[p.name] = { name: p.name, cpu: 0, mem: 0 }
                    agg[p.name].cpu += p.cpu
                    agg[p.name].mem += p.mem
                }
                root.procModel = Object.values(agg)
                    .filter(p => p.cpu > 0.1 || p.mem > 0.3)
                    .sort((a, b) => b.cpu - a.cpu)
                    .slice(0, 8)
            }
        }
    }
    Timer {
        running: root.visible
        repeat: true
        interval: 4000
        triggeredOnStart: true
        onTriggered: procTop.running = true
    }

    function fmtDuration(sec) {
        sec = Math.round(sec)
        if (sec <= 0) return "—"
        const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60)
        if (h > 0) return `${h}h ${m}m`
        if (m > 0) return `${m}m`
        return `${sec}s`
    }
    function timeAgo(epoch) {
        return (!epoch) ? "—" : fmtDuration(Battery.nowSec() - epoch) + " ago"
    }
    function fmtBytes(b) {
        if (b >= 1e9) return `${(b / 1e9).toFixed(2)} GB`
        if (b >= 1e6) return `${(b / 1e6).toFixed(1)} MB`
        if (b >= 1e3) return `${(b / 1e3).toFixed(0)} KB`
        return `${Math.round(b)} B`
    }

    component InfoRow: RowLayout {
        property string label: ""
        property string value: ""
        property color valueColor: Appearance.colors.colOnSurface
        Layout.fillWidth: true
        spacing: 12
        StyledText {
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
            text: label
        }
        Item { Layout.fillWidth: true }
        StyledText {
            font.pixelSize: Appearance.font.pixelSize.small
            color: valueColor
            horizontalAlignment: Text.AlignRight
            text: value
        }
    }

    // ── 1. Status ─────────────────────────────────────────────────────────────
    ContentSection {
        icon: "battery_full"
        title: Translation.tr("Battery")

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                MaterialSymbol {
                    iconSize: 52
                    text: Battery.isCharging ? "battery_charging_full"
                        : Battery.percentage > 0.9 ? "battery_full"
                        : Battery.percentage > 0.6 ? "battery_5_bar"
                        : Battery.percentage > 0.35 ? "battery_3_bar"
                        : Battery.percentage > 0.15 ? "battery_2_bar"
                        : "battery_alert"
                    color: Battery.isCritical ? Appearance.colors.colError
                        : Battery.isCharging ? Appearance.colors.colPrimary
                        : Appearance.colors.colOnSurface
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    StyledText {
                        font.pixelSize: Appearance.font.pixelSize.hugeass
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnSurface
                        text: `${Math.round(Battery.percentage * 100)}%`
                    }
                    StyledText {
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colSubtext
                        text: {
                            if (!Battery.available) return "No battery"
                            if (Battery.isCharging) return Battery.timeToFull > 0
                                ? `Charging · ${fmtDuration(Battery.timeToFull)} until full`
                                : "Charging"
                            if (Battery.isPluggedIn) return "Plugged in, not charging"
                            return Battery.timeToEmpty > 0
                                ? `On battery · ${fmtDuration(Battery.timeToEmpty)} left`
                                : "On battery"
                        }
                    }
                }

                ColumnLayout {
                    spacing: 1
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        font.pixelSize: Appearance.font.pixelSize.larger
                        font.weight: Font.Medium
                        color: Battery.isCharging ? Appearance.colors.colPrimary
                            : Battery.isCritical ? Appearance.colors.colError
                            : Appearance.colors.colOnSurface
                        text: `${Math.abs(Battery.energyRate).toFixed(1)}W`
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                        text: Battery.isCharging ? "charging" : "draw"
                    }
                }
            }

            StyledProgressBar {
                Layout.fillWidth: true
                value: Battery.percentage
                highlightColor: Battery.isCritical ? Appearance.colors.colError
                    : Battery.isCharging ? Appearance.colors.colPrimary
                    : Appearance.colors.colOnSurface
            }
        }

        InfoRow {
            label: "Power source"
            value: Battery.isPluggedIn ? "AC adapter" : "Battery"
        }
    }

    // ── 2. Usage time ─────────────────────────────────────────────────────────
    ContentSection {
        icon: "schedule"
        title: Translation.tr("Usage")

        InfoRow {
            label: "On battery for"
            value: Battery.isPluggedIn ? "Plugged in" : fmtDuration(Battery.onBatterySeconds)
        }
        InfoRow {
            label: "Screen on (since unplug)"
            value: Battery.isPluggedIn ? "—" : fmtDuration(Battery.screenOnSeconds)
        }
        InfoRow {
            label: "Last full charge"
            value: timeAgo(Battery.lastFullTime)
        }
    }

    // ── 3. Health ─────────────────────────────────────────────────────────────
    ContentSection {
        icon: "cardiology"
        title: Translation.tr("Health")

        InfoRow {
            label: "Battery health"
            value: Battery.health < 0 ? "—" : `${Math.round(Battery.health)}%`
            valueColor: Battery.health > 0 && Battery.health < 80
                ? Appearance.colors.colError : Appearance.colors.colOnSurface
        }
        InfoRow {
            label: "Charge cycles"
            value: Battery.cycleCount > 0 ? `${Battery.cycleCount}` : "—"
        }
        InfoRow {
            label: "Capacity now / design"
            value: Battery.energyFull > 0
                ? `${Battery.energyFull.toFixed(1)} / ${Battery.energyFullDesign.toFixed(1)} Wh`
                : "—"
        }
        InfoRow {
            label: "Voltage"
            value: Battery.voltage > 0 ? `${Battery.voltage.toFixed(2)} V` : "—"
        }
        InfoRow {
            label: "Technology"
            value: Battery.technology || "—"
        }
    }

    // ── 4. What's using power ─────────────────────────────────────────────────
    ContentSection {
        id: powerSection
        icon: "monitoring"
        title: Translation.tr("What's using power")

        // Total CPU across all shown processes — used for share calculation
        property real totalCpu: {
            let t = 0
            for (let i = 0; i < root.procModel.length; i++) t += root.procModel[i].cpu
            return Math.max(t, 0.01)
        }
        // Current draw in watts (positive = discharging)
        property real drawWatts: Math.abs(Battery.energyRate)

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            StyledText {
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
                text: `${powerSection.drawWatts.toFixed(1)} W total`
            }
            Item { Layout.fillWidth: true }
            RippleButton {
                implicitWidth: 30; implicitHeight: 30
                buttonRadius: Appearance.rounding.full
                downAction: () => { procTop.running = true }
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "refresh"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnSurface
                }
            }
        }

        Repeater {
            model: root.procModel
            delegate: ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 3

                readonly property real estWatts: (modelData.cpu / 100) * powerSection.drawWatts
                readonly property real cpuShare: modelData.cpu / powerSection.totalCpu

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: modelData.name
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnSurface
                    }
                    StyledText {
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: cpuShare > 0.4 ? Appearance.colors.colError
                            : cpuShare > 0.2 ? Appearance.colors.colTertiary
                            : Appearance.colors.colOnSurface
                        text: `${Math.round(cpuShare * 100)}%`
                    }
                }

                StyledProgressBar {
                    Layout.fillWidth: true
                    value: Math.min(1, modelData.cpu / 100)
                    highlightColor: modelData.cpu > 50 ? Appearance.colors.colError
                        : modelData.cpu > 20 ? Appearance.colors.colTertiary
                        : Appearance.colors.colPrimary
                }

                RowLayout {
                    spacing: 10
                    StyledText {
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colSubtext
                        text: `${modelData.cpu.toFixed(1)}% CPU`
                    }
                    StyledText {
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colSubtext
                        text: `~${estWatts.toFixed(2)} W`
                    }
                    StyledText {
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colSubtext
                        opacity: 0.6
                        text: `${modelData.mem.toFixed(1)}% RAM`
                    }
                }
            }
        }

        StyledText {
            visible: root.procModel.length === 0
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
            text: "Reading processes…"
        }

    }

    // ── 5. Battery history ────────────────────────────────────────────────────
    ContentSection {
        id: historySection
        icon: "show_chart"
        title: Translation.tr("Battery history")

        property int rangeDays: 1

        function filteredSamples() {
            const now = Math.floor(Date.now() / 1000)
            const cutoff = rangeDays >= 9999 ? 0 : now - rangeDays * 86400
            return Battery.batteryHistory.filter(s => s[0] >= cutoff)
        }

        // Downsample to target count, returning raw sample objects.
        function downsampleRaw(samples, target) {
            if (samples.length <= target) return samples
            const step = samples.length / target
            const out = []
            for (let i = 0; i < target; i++) out.push(samples[Math.floor(i * step)])
            return out
        }

        // Find biggest drops: [{ t, drop, topProc }]
        function dropEvents(samples) {
            const events = []
            for (let i = 1; i < samples.length; i++) {
                const drop = samples[i - 1][1] - samples[i][1]
                if (drop < 2) continue
                // top proc: new format has procs in [3], old in [2]
                let top = ""
                if (samples[i].length >= 4 && typeof samples[i][3] === "string")
                    top = samples[i][3].split(",")[0]?.split(":")[0] ?? ""
                else if (samples[i].length >= 3 && typeof samples[i][2] === "string")
                    top = samples[i][2]
                events.push({ t: samples[i][0], drop, top })
            }
            return events.sort((a, b) => b.drop - a.drop).slice(0, 6)
        }

        // Screen time per app: sum interval durations where proc appears in top list.
        // Returns [{ name, secs }] sorted by secs desc.
        function screenTimeByApp(samples) {
            const appSecs = {}
            for (let i = 1; i < samples.length; i++) {
                const s = samples[i], prev = samples[i - 1]
                const dur = s[0] - prev[0]
                if (dur <= 0 || dur > 5400) continue  // skip suspend gaps > 90 min
                if (s.length < 4 || typeof s[3] !== "string" || s[3] === "") continue
                const seen = new Set(s[3].split(",").map(p => p.split(":")[0]?.trim()).filter(Boolean))
                for (const name of seen)
                    appSecs[name] = (appSecs[name] || 0) + dur
            }
            return Object.entries(appSecs)
                .map(([name, secs]) => ({ name, secs }))
                .sort((a, b) => b.secs - a.secs)
                .slice(0, 8)
        }

        // Total system RX/TX in range (bytes) from absolute /proc/net/dev counters.
        // Delta < 0 = reboot counter reset → skip that interval.
        function netDataForRange(samples) {
            let rx = 0, tx = 0
            for (let i = 1; i < samples.length; i++) {
                const s = samples[i], prev = samples[i - 1]
                if (s.length < 6 || prev.length < 6) continue
                const drx = s[4] - prev[4], dtx = s[5] - prev[5]
                if (drx > 0 && drx < 1e11) rx += drx
                if (dtx > 0 && dtx < 1e11) tx += dtx
            }
            return { rx, tx }
        }

        // Compute estimated Wh per app from samples with proc data.
        // New format: [t, pct, watts, "proc:cpu,..."]
        // Returns [{ name, wh }] sorted by wh desc, plus maxWh
        function appProfile(samples) {
            const appWh = {}
            for (let i = 1; i < samples.length; i++) {
                const s = samples[i], prev = samples[i - 1]
                const dur_h = (s[0] - prev[0]) / 3600
                if (dur_h <= 0 || dur_h > 1.5) continue  // gap = suspend
                // Only new-format samples have proc+watts
                if (s.length < 4 || typeof s[3] !== "string" || s[3] === "") continue
                const watts = typeof s[2] === "number" ? s[2] : 0
                if (watts <= 0) continue
                const procs = s[3].split(",").map(p => {
                    const [name, cpu] = p.split(":")
                    return { name: name?.trim(), cpu: parseFloat(cpu) || 0 }
                }).filter(p => p.name && p.cpu > 0)
                if (!procs.length) continue
                const totalCpu = procs.reduce((a, p) => a + p.cpu, 0)
                const windowWh = watts * dur_h
                for (const p of procs)
                    appWh[p.name] = (appWh[p.name] || 0) + (p.cpu / totalCpu) * windowWh
            }
            const items = Object.entries(appWh)
                .map(([name, wh]) => ({ name, wh }))
                .sort((a, b) => b.wh - a.wh)
                .slice(0, 8)
            const maxWh = items[0]?.wh ?? 1
            return { items, maxWh }
        }

        // Range tabs
        RowLayout {
            spacing: 4
            Repeater {
                model: [
                    { label: "1 Day",   d: 1 },
                    { label: "7 Days",  d: 7 },
                    { label: "30 Days", d: 30 },
                    { label: "All",     d: 9999 },
                ]
                delegate: RippleButton {
                    required property var modelData
                    buttonRadius: Appearance.rounding.small
                    toggled: historySection.rangeDays === modelData.d
                    implicitWidth: 70
                    implicitHeight: 30
                    downAction: () => { historySection.rangeDays = modelData.d }
                    contentItem: StyledText {
                        anchors.centerIn: parent
                        text: modelData.label
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnSurface
                    }
                }
            }
        }

        // Battery history graph
        Item {
            id: graphArea
            Layout.fillWidth: true
            height: 200

            property var _samples: historySection.filteredSamples()
            property var _ds: historySection.downsampleRaw(_samples, 300)
            property real _lo: _ds.length >= 2 ? Math.max(0,   Math.min(..._ds.map(s => s[1])) - 8) : 0
            property real _hi: _ds.length >= 2 ? Math.min(100, Math.max(..._ds.map(s => s[1])) + 8) : 100
            property real _range: Math.max(_hi - _lo, 1)
            readonly property int _plotHeight: height - 20

            // Horizontal grid lines at standard battery levels
            Item {
                anchors { left: parent.left; right: yAxis.left; top: parent.top; rightMargin: 6 }
                height: graphArea._plotHeight
                Repeater {
                    model: [25, 50, 75, 100]
                    delegate: Rectangle {
                        required property int modelData
                        visible: modelData > graphArea._lo && modelData <= graphArea._hi
                        width: parent.width; height: 1
                        y: (1 - (modelData - graphArea._lo) / graphArea._range) * parent.height
                        color: Appearance.colors.colOutlineVariant; opacity: 0.3
                    }
                }
            }

            Graph {
                id: historyGraph
                anchors { left: parent.left; right: yAxis.left; top: parent.top; rightMargin: 6 }
                height: graphArea._plotHeight
                values: graphArea._ds.length < 2 ? [0.5, 0.5] :
                    graphArea._ds.map(s => (s[1] - graphArea._lo) / graphArea._range)
                color: Appearance.colors.colPrimary
                fillOpacity: 0.18
            }

            // Current level indicator
            Rectangle {
                visible: graphArea._ds.length >= 2
                anchors { left: parent.left; right: yAxis.left; rightMargin: 6 }
                height: 1
                y: (1 - Math.max(0, Math.min(1, (Battery.percentage * 100 - graphArea._lo) / graphArea._range))) * graphArea._plotHeight
                color: Battery.isCharging ? Appearance.colors.colPrimary
                     : Battery.isCritical ? Appearance.colors.colError
                     : Appearance.colors.colSecondary
                opacity: 0.7
            }

            // Y-axis
            Column {
                id: yAxis
                anchors { right: parent.right; top: parent.top }
                height: graphArea._plotHeight
                width: 36
                spacing: 0
                StyledText {
                    width: parent.width; horizontalAlignment: Text.AlignRight
                    text: Math.round(graphArea._hi) + "%"
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext; opacity: 0.7
                }
                Item { height: graphArea._plotHeight / 2 - 16 }
                StyledText {
                    width: parent.width; horizontalAlignment: Text.AlignRight
                    text: Math.round((graphArea._lo + graphArea._hi) / 2) + "%"
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext; opacity: 0.7
                }
                Item { height: graphArea._plotHeight / 2 - 16 }
                StyledText {
                    width: parent.width; horizontalAlignment: Text.AlignRight
                    text: Math.round(graphArea._lo) + "%"
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext; opacity: 0.7
                }
            }

            // X-axis time labels
            Row {
                anchors { left: parent.left; right: yAxis.left; bottom: parent.bottom; rightMargin: 6 }
                height: 18
                visible: graphArea._ds.length >= 2
                StyledText {
                    width: parent.width / 3; horizontalAlignment: Text.AlignLeft
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext; opacity: 0.5
                    text: historySection.rangeDays === 1
                        ? new Date(graphArea._ds[0][0] * 1000).toLocaleTimeString(Qt.locale(), "HH:mm")
                        : new Date(graphArea._ds[0][0] * 1000).toLocaleDateString(Qt.locale(), "d MMM")
                }
                StyledText {
                    width: parent.width / 3; horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext; opacity: 0.5
                    text: historySection.rangeDays === 1
                        ? new Date(graphArea._ds[Math.floor(graphArea._ds.length / 2)][0] * 1000).toLocaleTimeString(Qt.locale(), "HH:mm")
                        : new Date(graphArea._ds[Math.floor(graphArea._ds.length / 2)][0] * 1000).toLocaleDateString(Qt.locale(), "d MMM")
                }
                StyledText {
                    width: parent.width / 3; horizontalAlignment: Text.AlignRight
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext; opacity: 0.5
                    text: historySection.rangeDays === 1
                        ? new Date(graphArea._ds[graphArea._ds.length - 1][0] * 1000).toLocaleTimeString(Qt.locale(), "HH:mm")
                        : new Date(graphArea._ds[graphArea._ds.length - 1][0] * 1000).toLocaleDateString(Qt.locale(), "d MMM")
                }
            }
        }

        // Stats strip
        RowLayout {
            id: statsRow
            Layout.fillWidth: true
            spacing: 0
            property var _s: historySection.filteredSamples()
            property var _p: _s.length >= 2 ? _s.map(x => x[1]) : []

            Repeater {
                model: statsRow._p.length >= 2 ? [
                    { label: "Min", val: Math.min(...statsRow._p) + "%" },
                    { label: "Avg", val: Math.round(statsRow._p.reduce((a,b)=>a+b,0)/statsRow._p.length) + "%" },
                    { label: "Max", val: Math.max(...statsRow._p) + "%" },
                    { label: "Now", val: Math.round(Battery.percentage * 100) + "%" },
                ] : []
                delegate: ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 3
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                        text: modelData.label
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        font.pixelSize: Appearance.font.pixelSize.larger
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnSurface
                        text: modelData.val
                    }
                }
            }
        }

        // ── Per-app power usage ──────────────────────────────────────────────
        ColumnLayout {
            id: appProfileSection
            Layout.fillWidth: true
            spacing: 6
            property var _profile: historySection.appProfile(historySection.filteredSamples())

            Rectangle { Layout.fillWidth: true; height: 1; color: Appearance.colors.colOutlineVariant; opacity: 0.35 }

            StyledText {
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: Appearance.colors.colOnSurface
                text: "Power by app"
            }

            StyledText {
                visible: appProfileSection._profile.items.length === 0
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
                text: "Building data — check back after using your device on battery."
            }

            Repeater {
                model: appProfileSection._profile.items
                delegate: ColumnLayout {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        StyledText {
                            Layout.preferredWidth: 18
                            horizontalAlignment: Text.AlignRight
                            text: `${index + 1}`
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                            opacity: 0.5
                        }

                        StyledText {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: modelData.name
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnSurface
                        }

                        StyledText {
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                            opacity: 0.7
                            text: `${Math.round(modelData.wh / appProfileSection._profile.maxWh * 100)}%`
                        }

                        StyledText {
                            Layout.preferredWidth: 60
                            horizontalAlignment: Text.AlignRight
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnSurface
                            text: modelData.wh >= 1
                                ? `${modelData.wh.toFixed(2)} Wh`
                                : `${(modelData.wh * 1000).toFixed(0)} mWh`
                        }
                    }

                    StyledProgressBar {
                        Layout.fillWidth: true
                        value: modelData.wh / appProfileSection._profile.maxWh
                        highlightColor: index === 0 ? Appearance.colors.colError
                            : index <= 2 ? Appearance.colors.colTertiary
                            : Appearance.colors.colPrimary
                    }
                }
            }
        }

        // ── Data usage ───────────────────────────────────────────────────────
        ColumnLayout {
            id: dataUsageSection
            Layout.fillWidth: true
            spacing: 6
            property var _net: historySection.netDataForRange(historySection.filteredSamples())

            Rectangle { Layout.fillWidth: true; height: 1; color: Appearance.colors.colOutlineVariant; opacity: 0.35 }

            StyledText {
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: Appearance.colors.colOnSurface
                text: "Data usage"
            }

            StyledText {
                visible: dataUsageSection._net.rx === 0 && dataUsageSection._net.tx === 0
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
                text: "No data recorded in this range yet."
            }

            RowLayout {
                visible: dataUsageSection._net.rx > 0 || dataUsageSection._net.tx > 0
                Layout.fillWidth: true
                spacing: 0

                Repeater {
                    model: [
                        { label: "Downloaded", val: root.fmtBytes(dataUsageSection._net.rx) },
                        { label: "Uploaded",   val: root.fmtBytes(dataUsageSection._net.tx) },
                        { label: "Total",      val: root.fmtBytes(dataUsageSection._net.rx + dataUsageSection._net.tx) },
                    ]
                    delegate: ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 2
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                            text: modelData.label
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnSurface
                            text: modelData.val
                        }
                    }
                }
            }

        }

        // ── Biggest drops ────────────────────────────────────────────────────
        ColumnLayout {
            id: dropsSection
            Layout.fillWidth: true
            spacing: 6
            property var _drops: historySection.dropEvents(historySection.filteredSamples())

            Rectangle { Layout.fillWidth: true; height: 1; color: Appearance.colors.colOutlineVariant; opacity: 0.35 }

            StyledText {
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: Appearance.colors.colOnSurface
                text: "Biggest drops"
            }

            StyledText {
                visible: dropsSection._drops.length === 0
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
                text: "No discharge in this range."
            }

            Repeater {
                model: dropsSection._drops
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        width: 46; height: 24; radius: Appearance.rounding.small
                        color: Qt.alpha(modelData.drop >= 8
                            ? Appearance.colors.colError : Appearance.colors.colTertiary, 0.18)
                        StyledText {
                            anchors.centerIn: parent
                            text: `-${modelData.drop}%`
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            color: modelData.drop >= 8 ? Appearance.colors.colError : Appearance.colors.colTertiary
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: modelData.top !== "" ? modelData.top : "—"
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: modelData.top !== "" ? Appearance.colors.colOnSurface : Appearance.colors.colSubtext
                    }

                    StyledText {
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                        text: {
                            const d = new Date(modelData.t * 1000)
                            return d.toLocaleDateString(Qt.locale(), "d MMM") + "  " + d.toLocaleTimeString(Qt.locale(), "HH:mm")
                        }
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            opacity: 0.6
            text: {
                const s = historySection.filteredSamples()
                if (s.length < 2) return "No history"
                const fmt = "d MMM yyyy"
                const from = new Date(s[0][0] * 1000).toLocaleDateString(Qt.locale(), fmt)
                const to   = new Date(s[s.length - 1][0] * 1000).toLocaleDateString(Qt.locale(), fmt)
                return `${s.length} samples  ·  ${from} → ${to}`
            }
        }
    }
}
