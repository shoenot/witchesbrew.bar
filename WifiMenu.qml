import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "."

PopupWindow {
    id: popup

    color: "transparent"
    implicitWidth: 300
    implicitHeight: contentCol.implicitHeight + 38

    required property var networkStatus

    // ── Scan for networks when popup opens ─────────────────────────────
    onVisibleChanged: {
        if (visible) {
            _scan();
            _fetchSavedConnections();
        } else {
            _promptSsid = "";
            _connectError = "";
            _connecting = false;
        }
    }

    property var _networks: []
    property bool _scanning: false
    property bool _wifiAvailable: false

    // ── Password prompt state ──────────────────────────────────────────
    property string _promptSsid: ""
    property bool _connecting: false
    property string _connectError: ""
    property var _savedConnections: []

    function _scan() {
        _scanning = true;
        _checkProc.running = false;
        _checkProc.running = true;
    }

    // Check saved connections so we know which networks don't need a password
    function _fetchSavedConnections() {
        _savedProc.running = false;
        _savedProc.running = true;
    }

    Process {
        id: _savedProc
        command: ["nmcli", "-t", "-f", "NAME", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                popup._savedConnections = this.text.trim().split("\n").filter(n => n !== "");
            }
        }
    }

    // First check if wifi device is available
    Process {
        id: _checkProc
        command: ["nmcli", "-t", "-f", "TYPE,STATE", "device", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n");
                let wifiOk = false;
                for (let line of lines) {
                    let parts = line.split(":");
                    if (parts[0] === "wifi" && parts[1] !== "unavailable" && parts[1] !== "unmanaged") {
                        wifiOk = true;
                        break;
                    }
                }
                popup._wifiAvailable = wifiOk;
                if (wifiOk) {
                    _scanProc.running = false;
                    _scanProc.running = true;
                } else {
                    popup._networks = [];
                    popup._scanning = false;
                }
            }
        }
    }

    Process {
        id: _scanProc
        command: ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY,IN-USE", "dev", "wifi", "list", "--rescan", "auto"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n");
                let nets = [];
                let seen = new Set();
                for (let line of lines) {
                    let parts = line.split(":");
                    if (parts.length < 4) continue;
                    let ssid = parts[0];
                    if (!ssid || ssid === "--" || seen.has(ssid)) continue;
                    seen.add(ssid);
                    let signal = parseInt(parts[1]) || 0;
                    let security = parts[2] || "";
                    let inUse = parts[3] === "*";
                    nets.push({ ssid: ssid, signal: signal, security: security, inUse: inUse });
                }
                nets.sort((a, b) => {
                    if (a.inUse !== b.inUse) return a.inUse ? -1 : 1;
                    return b.signal - a.signal;
                });
                popup._networks = nets;
                popup._scanning = false;
            }
        }
    }

    // ── Connect / disconnect processes ─────────────────────────────────
    Process {
        id: _connectProc
        stdout: StdioCollector {
            onStreamFinished: {
                let out = this.text.trim();
                if (out.indexOf("successfully") !== -1) {
                    popup._promptSsid = "";
                    popup._connectError = "";
                    popup._connecting = false;
                    popup._scan();
                } else {
                    popup._connecting = false;
                    popup._connectError = "Connection failed";
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                let err = this.text.trim();
                if (err !== "") {
                    popup._connecting = false;
                    if (err.indexOf("Secrets were required") !== -1 || err.indexOf("No suitable") !== -1) {
                        popup._connectError = "Wrong password";
                    } else {
                        popup._connectError = "Connection failed";
                    }
                }
            }
        }
    }

    Process { id: _disconnectProc }

    function _isSaved(ssid) {
        return _savedConnections.indexOf(ssid) !== -1;
    }

    function connectTo(ssid, security) {
        let isSecured = security !== "" && security !== "--";
        if (!isSecured || _isSaved(ssid)) {
            // Open network or already saved — connect directly
            _connecting = true;
            _connectError = "";
            _connectProc.command = ["nmcli", "device", "wifi", "connect", ssid];
            _connectProc.running = true;
        } else {
            // Secured network without saved profile — prompt for password
            _promptSsid = ssid;
            _connectError = "";
        }
    }

    function connectWithPassword(ssid, password) {
        _connecting = true;
        _connectError = "";
        _connectProc.command = ["nmcli", "device", "wifi", "connect", ssid, "password", password];
        _connectProc.running = true;
    }

    function disconnect() {
        _disconnectProc.command = ["nmcli", "device", "disconnect", networkStatus.interfaceName];
        _disconnectProc.running = true;
    }

    Process { id: nmLauncher; command: [Config.networkManagerCmd] }

    Rectangle {
        id: content
        anchors.fill: parent
        anchors.bottomMargin: 10
        color: Config.colBg
        border.width: 1
        border.color: Config.colBorder
        radius: Config.popupRadius

        // ── open animation ──
        opacity: 0
        transform: Translate { id: contentSlide; y: 8 }

        states: State {
            name: "open"; when: popup.visible
            PropertyChanges { target: content; opacity: 1 }
            PropertyChanges { target: contentSlide; y: 0 }
        }
        transitions: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; duration: Config.animDurationSlow; easing.type: Easing.OutCubic }
                NumberAnimation { property: "y"; duration: Config.animDurationSlow; easing.type: Easing.OutCubic }
            }
        }

        ColumnLayout {
            id: contentCol
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            // ── Header ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "NETWORK"
                    color: Config.colAccent
                    font { family: Config.fontFamily; pixelSize: 15; bold: true }
                    Layout.fillWidth: true
                }

                Text {
                    visible: popup._wifiAvailable
                    text: popup._scanning ? "󰑓" : "󰑐"
                    color: refreshMouse.containsMouse ? Config.colAccent : Config.colMuted
                    font { family: Config.fontFamily; pixelSize: 16 }

                    Behavior on color { ColorAnimation { duration: Config.animDurationFast } }

                    MouseArea {
                        id: refreshMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popup._scan()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Config.colWine
            }

            // ── Connection info ──
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: popup.networkStatus.icon
                        color: popup.networkStatus.iconColor
                        font { family: Config.fontFamily; pixelSize: Config.fontSize }
                    }

                    Text {
                        text: popup.networkStatus.displayText
                        color: popup.networkStatus.iconColor
                        font { family: Config.fontFamily; pixelSize: Config.fontSize; bold: true }
                        Layout.fillWidth: true
                    }
                }

                Text {
                    text: "Interface: " + (popup.networkStatus.interfaceName || "none")
                    color: Config.colMuted
                    font { family: Config.fontFamily; pixelSize: 12 }
                    Layout.leftMargin: 4
                }

                Text {
                    text: "WAN: " + (popup.networkStatus.wanAddress || "fetching…")
                    color: Config.colMuted
                    font { family: Config.fontFamily; pixelSize: 12 }
                    Layout.leftMargin: 4
                }
            }

            // ── Wi-Fi section ──
            Rectangle {
                visible: popup._wifiAvailable
                Layout.fillWidth: true
                height: 1
                color: Config.colWine
            }

            Text {
                visible: popup._wifiAvailable
                text: "WI-FI NETWORKS"
                color: Config.colMuted
                font { family: Config.fontFamily; pixelSize: 11; bold: true }
            }

            // ── Scanning indicator ──
            Text {
                visible: popup._scanning && popup._networks.length === 0
                text: "Scanning…"
                color: Config.colMuted
                font { family: Config.fontFamily; pixelSize: Config.fontSize; italic: true }
            }

            // ── No wifi message ──
            Text {
                visible: !popup._wifiAvailable && !popup._scanning
                text: "Wi-Fi adapter unavailable"
                color: Config.colMuted
                font { family: Config.fontFamily; pixelSize: Config.fontSize; italic: true }
            }

            // ── Connecting indicator ──
            Text {
                visible: popup._connecting
                text: "Connecting…"
                color: Config.colNetConnecting
                font { family: Config.fontFamily; pixelSize: Config.fontSize; italic: true }
            }

            // ── Network list ──
            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(netCol.implicitHeight, 250)
                contentHeight: netCol.implicitHeight
                clip: true
                visible: popup._networks.length > 0

                ColumnLayout {
                    id: netCol
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: popup._networks

                        delegate: Rectangle {
                            Layout.fillWidth: true
                            height: 34
                            radius: Config.popupRadius / 2
                            color: netItemMouse.containsMouse ? Config.colSurface : "transparent"

                            Behavior on color { ColorAnimation { duration: Config.animDurationFast } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10

                                // Signal icon
                                Text {
                                    text: {
                                        let s = modelData.signal;
                                        if (s > 75) return "󰤨";
                                        if (s > 50) return "󰤥";
                                        if (s > 25) return "󰤢";
                                        return "󰤟";
                                    }
                                    color: modelData.inUse ? Config.colNetConnected : Config.colMuted
                                    font { family: Config.fontFamily; pixelSize: Config.fontSize }
                                }

                                // SSID
                                Text {
                                    text: modelData.ssid
                                    color: modelData.inUse ? Config.colNetConnected : Config.colFg
                                    font {
                                        family: Config.fontFamily
                                        pixelSize: Config.fontSize
                                        bold: modelData.inUse
                                    }
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true

                                    Behavior on color { ColorAnimation { duration: Config.animDuration } }
                                }

                                // Lock icon for secured networks
                                Text {
                                    visible: modelData.security !== "" && modelData.security !== "--"
                                    text: "\uf456"
                                    color: Config.colMuted
                                    font { family: Config.fontFamily; pixelSize: 12 }
                                }

                                // Connected indicator
                                Text {
                                    visible: modelData.inUse
                                    text: "✓"
                                    color: Config.colNetConnected
                                    font { family: Config.fontFamily; pixelSize: 12; bold: true }
                                }
                            }

                            MouseArea {
                                id: netItemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.inUse) {
                                        popup.disconnect();
                                    } else {
                                        popup.connectTo(modelData.ssid, modelData.security);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Password prompt (outside Flickable) ──
            ColumnLayout {
                visible: popup._promptSsid !== ""
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Config.colWine
                }

                Text {
                    text: "Connect to " + popup._promptSsid
                    color: Config.colFg
                    font { family: Config.fontFamily; pixelSize: 13; bold: true }
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        Layout.fillWidth: true
                        height: 30
                        radius: Config.popupRadius / 2
                        color: Config.colSurface
                        border.width: 1
                        border.color: passwordInput.activeFocus ? Config.colAccent : Config.colWine

                        Behavior on border.color { ColorAnimation { duration: Config.animDurationFast } }

                        TextInput {
                            id: passwordInput
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            verticalAlignment: TextInput.AlignVCenter
                            color: Config.colFg
                            font { family: Config.fontFamily; pixelSize: 13 }
                            echoMode: TextInput.Password
                            clip: true

                            onVisibleChanged: {
                                if (visible) {
                                    text = "";
                                    forceActiveFocus();
                                }
                            }

                            Keys.onReturnPressed: {
                                if (text.length > 0) {
                                    popup.connectWithPassword(popup._promptSsid, text);
                                }
                            }

                            Keys.onEscapePressed: {
                                popup._promptSsid = "";
                                popup._connectError = "";
                            }

                            // Placeholder
                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "Password"
                                color: Config.colMuted
                                font: passwordInput.font
                                visible: !passwordInput.text && !passwordInput.activeFocus
                            }
                        }
                    }

                    // Connect button
                    Rectangle {
                        width: 30
                        height: 30
                        radius: Config.popupRadius / 2
                        color: connectBtnMouse.containsMouse ? Config.colAccent : Config.colSurface

                        Behavior on color { ColorAnimation { duration: Config.animDurationFast } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰁔"
                            color: connectBtnMouse.containsMouse ? Config.colBg : Config.colFg
                            font { family: Config.fontFamily; pixelSize: 14 }

                            Behavior on color { ColorAnimation { duration: Config.animDurationFast } }
                        }

                        MouseArea {
                            id: connectBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (passwordInput.text.length > 0) {
                                    popup.connectWithPassword(popup._promptSsid, passwordInput.text);
                                }
                            }
                        }
                    }

                    // Cancel button
                    Rectangle {
                        width: 30
                        height: 30
                        radius: Config.popupRadius / 2
                        color: cancelBtnMouse.containsMouse ? Config.colSurface : "transparent"

                        Behavior on color { ColorAnimation { duration: Config.animDurationFast } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            color: cancelBtnMouse.containsMouse ? Config.colPowerHover : Config.colMuted
                            font { family: Config.fontFamily; pixelSize: 14 }

                            Behavior on color { ColorAnimation { duration: Config.animDurationFast } }
                        }

                        MouseArea {
                            id: cancelBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                popup._promptSsid = "";
                                popup._connectError = "";
                            }
                        }
                    }
                }

                // Error message
                Text {
                    visible: popup._connectError !== ""
                    text: popup._connectError
                    color: Config.colNetNotConnected
                    font { family: Config.fontFamily; pixelSize: 12 }
                }
            }

            // ── Divider ──
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Config.colWine
            }

            // ── Open settings button ──
            Rectangle {
                Layout.fillWidth: true
                height: 30
                radius: Config.popupRadius / 2
                color: settingsMouse.containsMouse ? Config.colSurface : "transparent"

                Behavior on color { ColorAnimation { duration: Config.animDurationFast } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    Text {
                        text: "󰒓"
                        color: settingsMouse.containsMouse ? Config.colAccent : Config.colMuted
                        font { family: Config.fontFamily; pixelSize: 16 }
                        Behavior on color { ColorAnimation { duration: Config.animDurationFast } }
                    }

                    Text {
                        text: "Network Settings"
                        color: settingsMouse.containsMouse ? Config.colFg : Config.colMuted
                        font { family: Config.fontFamily; pixelSize: Config.fontSize }
                        Layout.fillWidth: true
                        Behavior on color { ColorAnimation { duration: Config.animDurationFast } }
                    }
                }

                MouseArea {
                    id: settingsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        nmLauncher.running = false;
                        nmLauncher.running = true;
                        popup.visible = false;
                    }
                }
            }
        }
    }
}
