import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: button
    property string day
    property int isToday
    property bool bold
    property int cellMonthDiff: 0
    property var cellViewingDate: null

    // Compute the actual AD date and its BS equivalent for this cell
    readonly property var cellAdDate: cellViewingDate
        ? new Date(cellViewingDate.getFullYear(), cellViewingDate.getMonth() + cellMonthDiff, day * 1)
        : null
    readonly property var cellBsDate: (Config.options?.calendar?.useNepali && cellAdDate)
        ? NepaliDate.toBS(cellAdDate)
        : null
    readonly property string holidayName: cellBsDate ? (NepaliDate.getHoliday(cellBsDate) ?? "") : ""

    Layout.fillWidth: false
    Layout.fillHeight: false
    implicitWidth: 38
    implicitHeight: 38

    toggled: (isToday == 1)
    buttonRadius: Appearance.rounding.small

    StyledToolTip {
        visible: holidayName !== ""
        text: holidayName
    }

    contentItem: Item {
        anchors.fill: parent

        StyledText {
            anchors.centerIn: parent
            text: day
            horizontalAlignment: Text.AlignHCenter
            font.weight: bold ? Font.DemiBold : Font.Normal
            color: (isToday == 1) ? Appearance.m3colors.m3onPrimary :
                (isToday == 0) ? Appearance.colors.colOnLayer1 :
                Appearance.colors.colOutlineVariant

            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }

        // BS day number overlay (top-right corner)
        StyledText {
            visible: cellBsDate !== null && !bold
            anchors {
                top: parent.top
                right: parent.right
                topMargin: 1
                rightMargin: 2
            }
            text: cellBsDate ? cellBsDate.day : ""
            font.pixelSize: Appearance.font.pixelSize.smallest - 1
            color: (isToday == 1) ? Appearance.m3colors.m3onPrimary :
                (isToday == 0) ? Appearance.colors.colOnSurfaceVariant :
                Appearance.colors.colOutlineVariant
        }

        // Holiday dot (bottom-center)
        Rectangle {
            visible: holidayName !== "" && !bold
            anchors {
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
                bottomMargin: 3
            }
            width: 4
            height: 4
            radius: 2
            color: (isToday == 1) ? Appearance.m3colors.m3onPrimary : Appearance.colors.colPrimary
        }
    }
}
