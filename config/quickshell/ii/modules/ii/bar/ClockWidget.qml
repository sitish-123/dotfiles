import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property bool borderless: Config.options.bar.borderless
    property bool showDate: Config.options.bar.verbose
    implicitWidth: rowLayout.implicitWidth
    implicitHeight: Appearance.sizes.barHeight

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent
        spacing: 4

        StyledText {
            font.pixelSize: Appearance.font.pixelSize.large
            color: Appearance.colors.colOnLayer1
            text: DateTime.time
        }

        StyledText {
            visible: root.showDate
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
            text: "•"
        }

        StyledText {
            visible: root.showDate
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
            text: Config.options?.calendar?.useNepali ? DateTime.nepaliDate : DateTime.longDate
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: !Config.options.bar.tooltips.clickToShow

        onClicked: Config.options.calendar.useNepali = !Config.options.calendar.useNepali

        // Scroll cycles: Gregorian → BS dayMonth → BS monthName → Gregorian
        onWheel: (event) => {
            const formats = ["dayMonth", "monthName", "short"]
            if (!Config.options.calendar.useNepali) {
                Config.options.calendar.useNepali = true
                Config.options.calendar.nepaliFormat = "dayMonth"
            } else {
                const cur = formats.indexOf(Config.options.calendar.nepaliFormat)
                const next = (cur + (event.angleDelta.y < 0 ? 1 : -1) + formats.length) % formats.length
                if (next === 0 && event.angleDelta.y > 0) {
                    Config.options.calendar.useNepali = false
                } else {
                    Config.options.calendar.nepaliFormat = formats[next]
                }
            }
        }

        ClockWidgetPopup {
            hoverTarget: mouseArea
        }
    }
}
