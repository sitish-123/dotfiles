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
    // Enterprise (802.1X / WPA-EAP): needs identity + password, not just a PSK.
    readonly property bool isEnterprise: security.includes("802.1X")
    // True when a saved NM connection profile already exists for this SSID. For
    // enterprise networks this means we can just `up` the profile (reusing the
    // stored EAP secrets) instead of re-prompting for identity/password.
    readonly property bool saved: lastIpcObject.saved ?? false

    // Derived, for the revamped UI.
    readonly property string band: frequency >= 4000 ? "5 GHz" : "2.4 GHz"
    readonly property string securityLabel: !isSecure ? "Open"
        : isEnterprise ? (security.includes("WPA3") ? "WPA3-Enterprise" : "WPA2-Enterprise")
        : security.includes("WPA3") ? "WPA3"
        : security.includes("WPA2") ? "WPA2"
        : security.includes("WPA")  ? "WPA"
        : security.includes("WEP")  ? "WEP"
        : "Secured"

    property bool askingPassword: false
    property bool expanded: false   // UI: details/actions panel open
}
