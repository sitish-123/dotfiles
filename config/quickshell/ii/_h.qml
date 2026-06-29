//@ pragma UseQApplication
import QtQuick
import QtQuick.Controls
ApplicationWindow { visible: true; width: 560; height: 720; color: "#1c1b1c"; title: "TESTPAGE"
    Loader { anchors.fill: parent; source: "modules/settings/BluetoothConfig.qml" } }
