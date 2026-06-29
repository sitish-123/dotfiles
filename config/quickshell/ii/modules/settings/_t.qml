import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import Quickshell
ContentPage {
    forceWidth: true
    ContentSection {
        icon: "wifi"; title: "Rows test"
        Repeater {
            model: ScriptModel { values: [1,2,3] }
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true; spacing: 10
                MaterialSymbol { text: "wifi"; iconSize: 24; color: "white" }
                StyledText { Layout.fillWidth: true; text: "Network " + modelData; color: "white" }
                DialogButton { buttonText: "Connect"; onClicked: {} }
            }
        }
    }
}
