import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.services

QuickToggleButton {
    toggled: Config.options.calendar.useNepali
    buttonIcon: "calendar_month"
    onClicked: Config.options.calendar.useNepali = !Config.options.calendar.useNepali
    StyledToolTip {
        text: Config.options.calendar.useNepali
            ? Translation.tr("Nepali (BS) — click for Gregorian")
            : Translation.tr("Gregorian — click for Nepali (BS)")
    }
}
