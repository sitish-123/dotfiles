import QtQuick

QtObject {
    required property var lastIpcObject
    readonly property string ssid: lastIpcObject.ssid
    readonly property string bssid: lastIpcObject.bssid
    readonly property int strength: lastIpcObject.strength
    readonly property int frequency: lastIpcObject.frequency
    readonly property bool active: lastIpcObject.active
    readonly property string security: lastIpcObject.security
    readonly property bool isSecure: security.length > 0

    // Derived, for the revamped UI.
    readonly property string band: frequency >= 4000 ? "5 GHz" : "2.4 GHz"
    readonly property string securityLabel: !isSecure ? "Open"
        : security.includes("WPA3") ? "WPA3"
        : security.includes("WPA2") ? "WPA2"
        : security.includes("WPA")  ? "WPA"
        : security.includes("WEP")  ? "WEP"
        : "Secured"

    property bool askingPassword: false
    property bool expanded: false   // UI: details/actions panel open
}
