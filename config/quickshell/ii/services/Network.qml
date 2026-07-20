pragma Singleton
pragma ComponentBehavior: Bound

// Took many bits from https://github.com/caelestia-dots/shell (GPLv3)

import Quickshell
import Quickshell.Io
import QtQuick
import qs.services.network

/**
 * Network service with nmcli.
 */
Singleton {
    id: root

    property bool wifi: true
    property bool ethernet: false

    property bool wifiEnabled: false
    property bool wifiScanning: false
    property bool wifiConnecting: connectProc.running || connectEnterpriseProc.running
    property WifiAccessPoint wifiConnectTarget
    // SSIDs of saved NM connection profiles (con-name == SSID here). Used to mark
    // scanned APs as `saved` so the UI can offer a one-tap reconnect instead of
    // re-prompting for credentials. Refreshed alongside every AP scan.
    property var savedWifiProfiles: []
    readonly property list<WifiAccessPoint> wifiNetworks: []
    // getNetworks mutates wifiNetworks in place (push/splice), which does NOT emit a
    // property-change signal — so bindings over wifiNetworks would go stale (the list
    // showed empty for ~8s in a cold process until a rescan happened to kick them).
    // Bump this after every mutation and depend on it in the derived bindings below.
    property int wifiNetworksRevision: 0
    readonly property WifiAccessPoint active: {
        root.wifiNetworksRevision;
        return wifiNetworks.find(n => n.active) ?? null;
    }
    // Active first, then by signal *bucketed* to 20% steps, then SSID alphabetically.
    // Bucketing + alphabetical tiebreak keeps the order STABLE: raw signal jitters by
    // a few % every scan, and sorting on it reordered the list under the user's finger
    // mid-password-entry. Buckets only reorder on a real signal change.
    readonly property list<var> friendlyWifiNetworks: {
        root.wifiNetworksRevision;
        return [...wifiNetworks].sort((a, b) => {
            if (a.active !== b.active)
                return a.active ? -1 : 1;
            const ba = Math.round((a.strength ?? 0) / 20);
            const bb = Math.round((b.strength ?? 0) / 20);
            if (ba !== bb)
                return bb - ba;
            return (a.ssid ?? "").localeCompare(b.ssid ?? "");
        });
    }
    // True while the user is mid-interaction (expanding a network, typing a password,
    // or a connect is in flight). Consumers pause the periodic rescan on this so the
    // list can't rebuild/reorder and destroy an open input form.
    readonly property bool userInteracting: wifiConnecting
        || (wifiConnectTarget !== null)
        || wifiNetworks.some(n => (n?.expanded ?? false) || (n?.askingPassword ?? false))
    property string wifiStatus: "disconnected"

    property string networkName: ""
    property int networkStrength
    // Live connection details for the connected Wi-Fi (shown inline, no external app).
    property string ipAddress: ""
    property string gateway: ""
    property string dns: ""
    property string materialSymbol: root.ethernet
        ? "lan"
        : (root.wifiEnabled && root.wifiStatus === "connected")
            ? (
                (root.active?.strength ?? 0) > 83 ? "signal_wifi_4_bar" :
                (root.active?.strength ?? 0) > 67 ? "network_wifi" :
                (root.active?.strength ?? 0) > 50 ? "network_wifi_3_bar" :
                (root.active?.strength ?? 0) > 33 ? "network_wifi_2_bar" :
                (root.active?.strength ?? 0) > 17 ? "network_wifi_1_bar" :
                "signal_wifi_0_bar"
            )
            : (root.wifiStatus === "connecting")
                ? "signal_wifi_statusbar_not_connected"
                : (root.wifiStatus === "disconnected")
                    ? "wifi_find"
                    : (root.wifiStatus === "disabled")
                        ? "signal_wifi_off"
                        : "signal_wifi_bad"

    // Control
    function enableWifi(enabled = true): void {
        const cmd = enabled ? "on" : "off";
        // Turning the radio off mid-scan would otherwise leave the spinner running
        // until scanSettle's ticks expire (~5s).
        if (!enabled) { scanSettle.stop(); root.wifiScanning = false; }
        enableWifiProc.exec(["nmcli", "radio", "wifi", cmd]);
    }

    function toggleWifi(): void {
        enableWifi(!wifiEnabled);
    }

    function rescanWifi(): void {
        // Guard re-entry: rescanProcess requests an ASYNC scan (returns in ~30ms) and
        // NM keeps delivering APs for a few seconds afterwards (tracked by scanSettle);
        // don't stack requests or the spinner would never rest.
        if (rescanProcess.running || scanSettle.running) return;
        wifiScanning = true;
        rescanProcess.running = true;
        getSavedProfiles.running = true;
    }

    function connectToWifiNetwork(accessPoint: WifiAccessPoint): void {
        // Ignore a new connect while one is in flight: connectProc and its onExited are
        // shared + overwrite wifiConnectTarget, so a second tap mid-connect would let
        // the first attempt's result (askingPassword/clear) land on the wrong AP.
        if (connectProc.running) return;
        accessPoint.askingPassword = false;
        accessPoint.connectError = "";
        root.wifiConnectTarget = accessPoint;
        // `dev wifi connect` also creates a profile (vs `connection up SSID`). Bound it
        // with --wait so a wrong stored password fails in ~25s and surfaces an error,
        // instead of NM retrying forever behind an endless "Connecting…" spinner.
        connectProc.exec(["nmcli", "--wait", "25", "dev", "wifi", "connect", accessPoint.ssid])

    }

    // Bring up an already-saved profile using its stored secrets — no delete, no
    // re-prompt. This is the fast-path for saved networks (crucially enterprise/
    // 802.1X, whose EAP password can't be re-supplied from a scan the way a PSK can),
    // so they don't ask for credentials again every session.
    function connectSavedNetwork(accessPoint: WifiAccessPoint): void {
        if (connectProc.running) return;   // one connect at a time (see connectToWifiNetwork)
        accessPoint.askingPassword = false;
        accessPoint.connectError = "";
        root.wifiConnectTarget = accessPoint;
        connectProc.exec(["nmcli", "--wait", "25", "connection", "up", "id", accessPoint.ssid]);
    }

    function disconnectWifiNetwork(): void {
        if (active) disconnectProc.exec(["nmcli", "connection", "down", active.ssid]);
    }

    // Abort an in-flight or stuck connect (e.g. a wrong stored password NM keeps
    // retrying). Terminates the nmcli connect proc, tears down NM's half-open
    // activation so its temp-disable/retry loop stops, and clears the UI state.
    function cancelConnect(): void {
        const t = root.wifiConnectTarget;
        connectProc.running = false;
        connectEnterpriseProc.running = false;
        if (t) {
            Quickshell.execDetached(["nmcli", "connection", "down", "id", t.ssid]);
            t.askingPassword = false;
            t.connectError = "";
        }
        root.wifiConnectTarget = null;
    }

    // WPA-Enterprise (802.1X): builds a connection profile with EAP + identity/password.
    // Defaults to PEAP / MSCHAPv2 (eduroam + most corporate). anonymousIdentity optional.
    function connectToWifiEnterprise(accessPoint: WifiAccessPoint, identity: string, password: string,
                                     eap = "peap", phase2 = "mschapv2", anonymousIdentity = ""): void {
        accessPoint.askingPassword = false;
        root.wifiConnectTarget = accessPoint;
        connectEnterpriseProc.exec({
            "environment": {
                "SSID": accessPoint.ssid,
                "IDENTITY": identity,
                "PASSWORD": password,
                "EAP": eap,
                "PHASE2": phase2,
                "ANON": anonymousIdentity
            },
            "command": ["bash", "-c",
                'dev=$(nmcli -t -f DEVICE,TYPE d | awk -F: \'$2=="wifi"{print $1; exit}\'); ' +
                'nmcli connection delete id "$SSID" >/dev/null 2>&1; ' +
                'nmcli connection add type wifi con-name "$SSID" ifname "$dev" ssid "$SSID" ' +
                'wifi-sec.key-mgmt wpa-eap 802-1x.eap "$EAP" 802-1x.phase2-auth "$PHASE2" ' +
                '802-1x.identity "$IDENTITY" 802-1x.password "$PASSWORD" ' +
                '${ANON:+802-1x.anonymous-identity "$ANON"} && ' +
                'nmcli connection up id "$SSID"'
            ]
        });
    }

    // Lightweight AP-list refresh (no rescan) — re-reads current APs/signal so the
    // open dialog stays in sync. rescanWifi() does the slow NIC rescan for new APs.
    function refreshNetworks(): void {
        getNetworks.running = true;
        getSavedProfiles.running = true;
    }

    // --- Share (QR + reveal password) ------------------------------------------
    property bool activeAutoconnect: true
    property string sharePassword: ""
    property string shareQrPath: ""
    property int shareNonce: 0
    // Load the connected network's password and render a Wi-Fi QR (WIFI:...;) to a PNG.
    function loadShareInfo(ssid: string): void {
        root.sharePassword = "";
        root.shareQrPath = "";
        root.shareNonce += 1;
        shareInfoProc.exec({
            "environment": { "SSID": ssid, "OUT": `/tmp/quickshell/wifi-qr-${root.shareNonce}.png` },
            "command": ["bash", "-c",
                // rm prior QR PNGs so at most the current one lingers in /tmp.
                'mkdir -p /tmp/quickshell; rm -f /tmp/quickshell/wifi-qr-*.png; ' +
                'PSK=$(nmcli -s -g 802-11-wireless-security.psk connection show "$SSID" 2>/dev/null); ' +
                'esc() { printf "%s" "$1" | sed \'s/\\\\/\\\\\\\\/g; s/;/\\\\;/g; s/,/\\\\,/g; s/:/\\\\:/g\'; }; ' +
                'if [ -n "$PSK" ]; then T=WPA; else T=nopass; fi; ' +
                'STR="WIFI:T:$T;S:$(esc "$SSID");P:$(esc "$PSK");;"; ' +
                'qrencode -o "$OUT" -s 8 -m 2 "$STR" 2>/dev/null; ' +
                'printf "%s" "$PSK"'
            ]
        });
    }
    Process {
        id: shareInfoProc
        property string buffer
        function exec(desc) { buffer = ""; command = desc.command; environment = desc.environment; running = true; }
        stdout: SplitParser { onRead: data => { shareInfoProc.buffer += data; } }
        onExited: (code, status) => {
            root.sharePassword = shareInfoProc.buffer;
            root.shareQrPath = `/tmp/quickshell/wifi-qr-${root.shareNonce}.png`;
        }
    }
    // Clear the revealed password + QR from memory and disk. Call when the share
    // panel closes so the PSK-bearing PNG doesn't linger in /tmp.
    function clearShareInfo(): void {
        root.sharePassword = "";
        root.shareQrPath = "";
        Quickshell.execDetached(["sh", "-c", "rm -f /tmp/quickshell/wifi-qr-*.png"]);
    }

    // --- Auto-connect toggle (for the connected network) -----------------------
    function setActiveAutoconnect(enabled): void {
        if (!active) return;
        autoconnectProc.exec(["nmcli", "connection", "modify", active.ssid, "connection.autoconnect", enabled ? "yes" : "no"]);
        root.activeAutoconnect = enabled;
    }
    Process { id: autoconnectProc }

    // --- Hidden network --------------------------------------------------------
    function connectHiddenNetwork(ssid: string, password: string): void {
        connectProc.exec(password.length > 0
            ? ["nmcli", "dev", "wifi", "connect", ssid, "password", password, "hidden", "yes"]
            : ["nmcli", "dev", "wifi", "connect", ssid, "hidden", "yes"]);
    }

    // Forget (delete) a saved network profile.
    function forgetWifiNetwork(ssid: string): void {
        forgetProc.exec(["nmcli", "connection", "delete", "id", ssid]);
    }

    Process {
        id: forgetProc
        stdout: SplitParser {
            onRead: getNetworks.running = true
        }
        onExited: {
            getSavedProfiles.running = true;
            root.update();
        }
    }

    function openPublicWifiPortal() {
        Quickshell.execDetached(["xdg-open", "https://nmcheck.gnome.org/"]) // From some StackExchange thread, seems to work
    }

    function changePassword(network: WifiAccessPoint, password: string, username = ""): void {
        // TODO: enterprise wifi with username
        network.askingPassword = false;
        network.connectError = "";
        // Keep the retry target alive: changePasswordProc.onExited re-attempts the
        // connect, and connectProc.onExited needs a non-null wifiConnectTarget.
        root.wifiConnectTarget = network;
        changePasswordProc.exec({
            "environment": {
                "PASSWORD": password,
                "SSID": network.ssid
            },
            "command": ["bash", "-c", 'nmcli connection modify "$SSID" wifi-sec.psk "$PASSWORD"']
        })
    }

    // --- Wi-Fi hotspot ---------------------------------------------------------
    // Backed by the root helper /usr/local/bin/ii-hotspot (installed by the
    // dotfiles; authorized passwordless via a polkit rule for the `wheel` group).
    // The helper picks the backend that actually works for the current uplink:
    //   • Wi-Fi is the uplink  -> create_ap: concurrent AP+STA on the ONE radio,
    //     so Wi-Fi STAYS connected and its internet is shared. A single radio
    //     can't span two channels, so the AP rides the client's channel and the
    //     requested band is ignored (hotspotBandLocked is true in this case).
    //   • Ethernet / Wi-Fi off -> NetworkManager AP: radio is free, band honoured.
    property bool hotspotActive: false
    property bool hotspotEnabling: false          // start/stop in flight
    property int hotspotClients: 0
    property string hotspotSsid: ""
    property string hotspotPassword: ""
    property string hotspotBand: "2.4"            // "2.4" | "5" (GHz)
    property string hotspotBackend: "none"        // "create_ap" | "nm" | "none"
    property bool hotspotConfigLoaded: false
    // On a single radio the band can't be chosen while Wi-Fi is the uplink — it
    // follows the client channel. The UI uses this to disable the band selector.
    readonly property bool hotspotBandLocked: root.wifi
    readonly property string hotspotHelper: "/usr/local/bin/ii-hotspot"

    function startHotspot(ssid: string, password: string, band = "2.4"): void {
        if (!ssid || ssid.length === 0) return;
        root.hotspotError = "";
        hotspotProc.errBuf = "";
        root.hotspotEnabling = true;
        root.hotspotSsid = ssid;
        root.hotspotPassword = password;
        root.hotspotBand = band;
        hotspotProc.exec(["pkexec", root.hotspotHelper, "start", ssid, password, band]);
    }

    function stopHotspot(): void {
        root.hotspotEnabling = true;
        stopHotspotProc.exec(["pkexec", root.hotspotHelper, "stop"]);
    }

    function toggleHotspot(): void {
        if (hotspotActive) stopHotspot();
        else startHotspot(hotspotSsid, hotspotPassword, hotspotBand);
    }

    // Load the saved Hotspot profile (or sensible defaults) to prefill the UI.
    // The helper mirrors config into an inactive NM "Hotspot" profile on every
    // start, so this prefills regardless of which backend last ran.
    function loadHotspotConfig(): void {
        hotspotConfigProc.exec(["bash", "-c",
            'if nmcli -t connection show Hotspot >/dev/null 2>&1; then ' +
            'echo "SSID:$(nmcli -g 802-11-wireless.ssid connection show Hotspot)"; ' +
            'echo "PSK:$(nmcli -s -g 802-11-wireless-security.psk connection show Hotspot)"; ' +
            'echo "BAND:$(nmcli -g 802-11-wireless.band connection show Hotspot)"; ' +
            'else echo "SSID:$(uname -n)"; echo "PSK:"; echo "BAND:bg"; fi'
        ]);
    }

    Process {
        id: hotspotProc
        property string errBuf: ""
        environment: ({ LANG: "C", LC_ALL: "C" })
        // Buffer all stderr; the helper prints progress lines even on success, so we
        // can't just keep the last line — we pick the meaningful reason on failure.
        stderr: SplitParser { onRead: line => { hotspotProc.errBuf += line + "\n"; } }
        onExited: (exitCode, exitStatus) => {
            root.hotspotEnabling = false;
            if (exitCode === 0) {
                root.hotspotError = "";
            } else {
                // Prefer the helper's own human-readable reason lines (prefixed
                // "ii-hotspot: "), skipping the "->" progress breadcrumb.
                const reasons = hotspotProc.errBuf.split("\n")
                    .filter(l => l.startsWith("ii-hotspot: ") && l.indexOf(" -> ") < 0)
                    .map(l => l.replace("ii-hotspot: ", "").trim())
                    .filter(l => l.length > 0);
                root.hotspotError = reasons.length ? reasons[0]
                    : (hotspotProc.errBuf.trim().split("\n").pop() || "Hotspot failed to start.");
            }
            hotspotProc.errBuf = "";
            root.update();
        }
    }
    property string hotspotError: ""

    Process {
        id: stopHotspotProc
        onExited: (exitCode, exitStatus) => {
            root.hotspotEnabling = false;
            root.update();
        }
    }

    Process {
        id: hotspotConfigProc
        property string buffer
        function exec(cmd) { buffer = ""; command = cmd; running = true; }
        stdout: SplitParser { onRead: data => { hotspotConfigProc.buffer += data + "\n"; } }
        onExited: (exitCode, exitStatus) => {
            hotspotConfigProc.buffer.trim().split("\n").forEach(line => {
                const idx = line.indexOf(":");
                if (idx < 0) return;
                const key = line.slice(0, idx), val = line.slice(idx + 1);
                if (key === "SSID" && val) root.hotspotSsid = val;
                else if (key === "PSK") root.hotspotPassword = val;
                // Map the stored NM band (bg/a) to the UI's 2.4/5 vocabulary.
                else if (key === "BAND" && val) root.hotspotBand = (val === "a") ? "5" : "2.4";
            });
            root.hotspotConfigLoaded = true;
        }
    }

    // Read hotspot state via the helper's read-only `status` (no privilege needed).
    // Runs from update() so a start/stop reflects live. If the helper isn't
    // installed yet, the command errors and we treat the hotspot as inactive.
    Process {
        id: hotspotStatusProc
        property string buffer
        command: [root.hotspotHelper, "status"]
        function startCheck() { buffer = ""; running = true; }
        stdout: SplitParser { onRead: data => { hotspotStatusProc.buffer += data + "\n"; } }
        onExited: (exitCode, exitStatus) => {
            let active = false, clients = 0, ssid = "", backend = "none";
            hotspotStatusProc.buffer.trim().split("\n").forEach(line => {
                const idx = line.indexOf(":");
                if (idx < 0) return;
                const key = line.slice(0, idx), val = line.slice(idx + 1);
                if (key === "ACTIVE") active = (val === "yes");
                else if (key === "BACKEND") backend = val;
                else if (key === "CLIENTS") clients = parseInt(val) || 0;
                else if (key === "SSID") ssid = val;
            });
            root.hotspotActive = active;
            root.hotspotClients = clients;
            root.hotspotBackend = backend;
            if (active && ssid) root.hotspotSsid = ssid;
        }
    }

    Process {
        id: enableWifiProc
    }

    Process {
        id: connectProc
        property string errBuf: ""
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        stdout: SplitParser {
            onRead: line => {
                getNetworks.running = true
            }
        }
        stderr: SplitParser {
            onRead: line => {
                connectProc.errBuf += line + "\n";
                // A wrong / again-needed PSK surfaces as one of these phrases; reveal the
                // password field immediately (before exit) so the user can retype.
                if (root.wifiConnectTarget
                    && (line.includes("Secrets were required")
                        || line.includes("encryption keys are required")
                        || line.includes("Passwords or encryption keys"))) {
                    root.wifiConnectTarget.askingPassword = true
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            // Guard the deref: the changePassword retry path re-runs this proc after the
            // first attempt already nulled the target — an unguarded write threw a
            // TypeError and silently killed the whole password-entry flow.
            if (root.wifiConnectTarget) {
                const failed = (exitCode !== 0);
                root.wifiConnectTarget.askingPassword = failed;
                // Classify the failure so the UI shows a real reason instead of a
                // silent endless spinner (the #1 "the Wi-Fi UI is broken" complaint).
                const e = connectProc.errBuf;
                root.wifiConnectTarget.connectError = !failed ? ""
                    : (e.includes("Secrets were required")
                       || e.includes("encryption keys are required")
                       || e.includes("Passwords or encryption keys")) ? "bad-password"
                    : e.includes("could not be found") ? "not-found"
                    : "failed";
            }
            connectProc.errBuf = "";
            root.wifiConnectTarget = null
            getSavedProfiles.running = true
        }
    }

    Process {
        id: disconnectProc
        stdout: SplitParser {
            onRead: getNetworks.running = true
        }
    }

    Process {
        id: connectEnterpriseProc
        environment: ({ LANG: "C", LC_ALL: "C" })
        onExited: (exitCode, exitStatus) => {
            // On failure, re-open the identity/password prompt so the user can retry.
            if (root.wifiConnectTarget)
                root.wifiConnectTarget.askingPassword = (exitCode !== 0);
            root.wifiConnectTarget = null;
            getNetworks.running = true;
            getSavedProfiles.running = true;
            root.update();
        }
    }

    Process {
        id: changePasswordProc
        onExited: { // Re-attempt connection after changing password
            // Re-issue against the tracked target (re-sets its command + askingPassword)
            // instead of blindly toggling connectProc, which could reconnect a stale SSID.
            if (root.wifiConnectTarget)
                root.connectToWifiNetwork(root.wifiConnectTarget);
        }
    }

    Process {
        id: rescanProcess
        // ASYNC scan request: `dev wifi rescan` returns in ~30ms. The old blocking
        // `list --rescan yes` waited ~6-8s for the scan AND starved concurrent
        // `nmcli d w` reads inside NetworkManager — that's what made the cold Wi-Fi
        // list take ~8s to paint. Here the cached list stays instantly readable;
        // scanSettle re-polls it as NM discovers new APs, then clears the spinner.
        command: ["nmcli", "dev", "wifi", "rescan"]
        property string errBuf: ""
        stderr: SplitParser { onRead: line => { rescanProcess.errBuf += line + "\n"; } }
        onExited: (code, status) => {
            getNetworks.running = true;
            // NM rate-limits rescans (~10-30s). When it refuses, no fresh scan happens,
            // so keep the cached list but stop the spinner promptly instead of implying
            // new results are coming (the "rescan just shows the old list" complaint).
            if (code !== 0 && rescanProcess.errBuf.includes("not allowed")) {
                scanSettle.stop();
                root.wifiScanning = false;
            } else {
                scanSettle.restart();
            }
            rescanProcess.errBuf = "";
        }
    }
    // Drives the scanning spinner + list refresh after an async rescan request:
    // NM finds APs over a few seconds, so poll a handful of times, then stop.
    Timer {
        id: scanSettle
        interval: 1200
        repeat: true
        property int ticks: 0
        onTriggered: {
            getNetworks.running = true;
            if (++ticks >= 4) { ticks = 0; stop(); root.wifiScanning = false; }
        }
    }

    // Status update. `nmcli monitor` emits a BURST of lines during any transition
    // (state + IP4 + connectivity), and each update() fans out to 6 nmcli/sh spawns —
    // so one Wi-Fi handshake would trigger 60-120 spawns (×2 with Settings open).
    // Coalesce the burst behind a short debounce (same pattern as HyprlandData).
    Timer { id: updateDebounce; interval: 200; repeat: false; onTriggered: root.doUpdate() }
    function update() { updateDebounce.restart(); }
    function doUpdate() {
        updateConnectionType.startCheck();
        wifiStatusProcess.running = true
        updateNetworkName.running = true;
        updateNetworkStrength.running = true;
        updateNetworkDetails.startCheck();
        hotspotStatusProc.startCheck();
    }

    Process {
        id: updateNetworkDetails
        property string buffer
        // IP / gateway / DNS of the connected wifi device (empty if none connected).
        command: ["sh", "-c", "dev=$(nmcli -t -f DEVICE,TYPE,STATE d | awk -F: '$2==\"wifi\"&&$3==\"connected\"{print $1; exit}'); [ -z \"$dev\" ] && exit 0; nmcli -t -f IP4.ADDRESS,IP4.GATEWAY,IP4.DNS device show \"$dev\"; con=$(nmcli -t -f GENERAL.CONNECTION device show \"$dev\" | cut -d: -f2-); echo \"AUTOCONNECT:$(nmcli -g connection.autoconnect connection show \"$con\" 2>/dev/null)\""]
        function startCheck() { buffer = ""; running = true; }
        stdout: SplitParser {
            onRead: data => { updateNetworkDetails.buffer += data + "\n"; }
        }
        onExited: (exitCode, exitStatus) => {
            let ip = "", gw = "", dns = [];
            updateNetworkDetails.buffer.trim().split("\n").forEach(line => {
                const idx = line.indexOf(":");
                if (idx < 0) return;
                const key = line.slice(0, idx), val = line.slice(idx + 1).trim();
                if (key.startsWith("IP4.ADDRESS") && !ip) ip = val;
                else if (key === "IP4.GATEWAY") gw = val;
                else if (key.startsWith("IP4.DNS")) dns.push(val);
                else if (key === "AUTOCONNECT") root.activeAutoconnect = (val === "yes");
            });
            root.ipAddress = ip;
            root.gateway = gw;
            root.dns = dns.join(", ");
        }
    }

    Process {
        id: subscriber
        running: true
        // setpriv --pdeathsig makes nmcli die with quickshell even on an unclean
        // exit (SIGSEGV / kill -9), instead of orphaning to init. Persistent
        // `nmcli monitor` orphans were piling up (one per crashed/killed shell or
        // settings process) and hogging memory.
        command: ["setpriv", "--pdeathsig", "TERM", "nmcli", "monitor"]
        stdout: SplitParser {
            onRead: root.update()
        }
    }

    Process {
        id: updateConnectionType
        property string buffer
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE d status && nmcli -t -f CONNECTIVITY g"]
        running: true
        function startCheck() {
            buffer = "";
            updateConnectionType.running = true;
        }
        stdout: SplitParser {
            onRead: data => {
                updateConnectionType.buffer += data + "\n";
            }
        }
        onExited: (exitCode, exitStatus) => {
            const lines = updateConnectionType.buffer.trim().split('\n');
            const connectivity = lines.pop() // none, limited, full
            let hasEthernet = false;
            let hasWifi = false;
            let wifiStatus = "disconnected";
            lines.forEach(line => {
                if (line.includes("ethernet") && line.includes("connected"))
                    hasEthernet = true;
                else if (line.includes("wifi:")) {
                    if (line.includes("disconnected")) {
                        wifiStatus = "disconnected"
                    }
                    else if (line.includes("connected")) {
                        hasWifi = true;
                        wifiStatus = "connected"

                        if (connectivity === "limited") {
                            hasWifi = false;
                            wifiStatus = "limited"
                        }
                    }
                    else if (line.includes("connecting")) {
                        wifiStatus = "connecting"
                    }
                    else if (line.includes("unavailable")) {
                        wifiStatus = "disabled"
                    }
                }
            });
            root.wifiStatus = wifiStatus;
            root.ethernet = hasEthernet;
            root.wifi = hasWifi;
        }
    }

    Process {
        id: updateNetworkName
        command: ["sh", "-c", "nmcli -t -f NAME c show --active | head -1"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                root.networkName = data;
            }
        }
    }

    Process {
        id: updateNetworkStrength
        running: true
        command: ["sh", "-c", "nmcli -f IN-USE,SIGNAL,SSID device wifi | awk '/^\\*/{if (NR!=1) {print $2}}'"]
        stdout: SplitParser {
            onRead: data => {
                const v = parseInt(data);
                root.networkStrength = isNaN(v) ? 0 : v;
            }
        }
    }

    Process {
        id: wifiStatusProcess
        command: ["nmcli", "radio", "wifi"]
        Component.onCompleted: running = true
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiEnabled = text.trim() === "enabled";
            }
        }
    }

    Process {
        id: getNetworks
        running: true
        // `--rescan no` = read NM's cached AP list ONLY (~25ms). Plain `d w` lets
        // nmcli decide, and when the cache is stale (>~30s, i.e. reopening settings
        // after a while) it triggers a blocking scan and WAITS ~6s — that was the
        // real cause of the slow/"Scanning…" empty list. Fresh APs come from the
        // async `dev wifi rescan` (rescanProcess) + scanSettle re-polling this.
        command: ["nmcli", "-g", "ACTIVE,SIGNAL,FREQ,SSID,BSSID,SECURITY", "device", "wifi", "list", "--rescan", "no"]
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        stdout: StdioCollector {
            onStreamFinished: {
                const PLACEHOLDER = "STRINGWHICHHOPEFULLYWONTBEUSED";
                const rep = new RegExp("\\\\:", "g");
                const rep2 = new RegExp(PLACEHOLDER, "g");

                const unesc = s => (s ?? "").replace(rep2, ":");
                const allNetworks = text.trim().split("\n").map(n => {
                    const net = n.replace(rep, PLACEHOLDER).split(":");
                    // Un-escape EVERY colon-bearing field, not just bssid. An SSID like
                    // "Guest:5G" otherwise keeps the placeholder and becomes the wrong
                    // connect/forget id, a garbled label, and misses the saved-match.
                    const ssid = unesc(net[3]);
                    return {
                        active: net[0] === "yes",
                        strength: parseInt(net[1]),
                        frequency: parseInt(net[2]),
                        ssid: ssid,
                        bssid: unesc(net[4]),
                        security: unesc(net[5]),
                        saved: root.savedWifiProfiles.includes(ssid)
                    };
                }).filter(n => n.ssid && n.ssid.length > 0);

                // Group networks by SSID and prioritize connected ones
                const networkMap = new Map();
                for (const network of allNetworks) {
                    const existing = networkMap.get(network.ssid);
                    if (!existing) {
                        networkMap.set(network.ssid, network);
                    } else {
                        // Prioritize active/connected networks
                        if (network.active && !existing.active) {
                            networkMap.set(network.ssid, network);
                        } else if (!network.active && !existing.active) {
                            // If both are inactive, keep the one with better signal
                            if (network.strength > existing.strength) {
                                networkMap.set(network.ssid, network);
                            }
                        }
                        // If existing is active and new is not, keep existing
                    }
                }

                const wifiNetworks = Array.from(networkMap.values());

                const rNetworks = root.wifiNetworks;

                // Don't destroy an AP the user is mid-interaction with: a single scan
                // can transiently drop a still-present AP (esp. the one being connected
                // to), and destroying it would tear down the open password form and the
                // typed password. Keep it until the user is done — it'll re-match next scan.
                const destroyed = rNetworks.filter(rn =>
                    !rn.askingPassword && !rn.expanded && rn !== root.wifiConnectTarget
                    && !wifiNetworks.find(n => n.ssid === rn.ssid));
                for (const network of destroyed)
                    rNetworks.splice(rNetworks.indexOf(network), 1).forEach(n => n.destroy());

                // Reconcile by SSID (wifiNetworks is already one-per-SSID). A phone
                // hotspot rotates its BSSID every scan; matching on BSSID destroyed +
                // recreated the row each time (flicker, stale phantoms, ScriptModel
                // churn). Match on SSID and update BSSID/signal in place.
                for (const network of wifiNetworks) {
                    const match = rNetworks.find(n => n.ssid === network.ssid);
                    if (match) {
                        match.lastIpcObject = network;
                    } else {
                        rNetworks.push(apComp.createObject(root, {
                            lastIpcObject: network
                        }));
                    }
                }
                // in-place push/splice above don't notify — kick the derived bindings
                root.wifiNetworksRevision++;
            }
        }
    }

    // Enumerate saved Wi-Fi connection profiles so scanned APs can be flagged
    // `saved`. NAME may contain escaped colons; TYPE is the trailing field.
    Process {
        id: getSavedProfiles
        running: true
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        environment: ({ LANG: "C", LC_ALL: "C" })
        stdout: StdioCollector {
            onStreamFinished: {
                const names = text.trim().split("\n").map(line => {
                    const idx = line.lastIndexOf(":");
                    if (idx < 0) return null;
                    const type = line.slice(idx + 1);
                    if (!type.includes("wireless")) return null;
                    return line.slice(0, idx).replace(/\\:/g, ":").replace(/\\\\/g, "\\");
                }).filter(Boolean);
                root.savedWifiProfiles = names;
                // Re-run the AP scan so existing entries pick up the new `saved` flag.
                getNetworks.running = true;
            }
        }
    }

    Component {
        id: apComp

        WifiAccessPoint {}
    }
}
