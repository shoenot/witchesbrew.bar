import Quickshell.Io
import QtQuick
import "."

QtObject {
    id: root

    // --- Public properties for the bar to consume ---

    readonly property string interfaceName: _device
    property string wanAddress: ""

    readonly property string icon: {
        if (_devType === "wifi") {
            if (_state !== "connected") return "󰤭"
            if (_signal > 75) return "󰤨"
            if (_signal > 50) return "󰤥"
            if (_signal > 25) return "󰤢"
            return "󰤟"
        }
        if (_devType === "ethernet") {
            return _state === "connected" ? "󰈀" : "󰤭"
        }
        return "󰤭"
    }

    readonly property color iconColor: {
        if (_state === "connected") return Config.colNetConnected
        if (_state === "connecting") return Config.colNetConnecting
        return Config.colNetNotConnected
    }

    readonly property string displayText: {
        if (_state === "connected") {
            if (_devType === "wifi") return _connection  // SSID
            return _ipAddress || _connection             // IP or connection name
        }
        if (_state === "connecting")    return "Connecting…"
        if (_state === "disconnecting") return "Disconnecting…"
        if (_state === "disconnected")  return "Disconnected"
        return "No Network"
    }

    // --- Internal state ---

    property string _devType: ""       // "ethernet" or "wifi"
    property string _state: ""         // "connected", "connecting", etc.
    property string _connection: ""    // connection/SSID name
    property string _device: ""        // interface name (e.g. enp42s0)
    property string _ipAddress: ""
    property int    _signal: 0         // wifi signal 0-100

    // --- Polling via nmcli ---

    property var _pollTimer: Timer {
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            _statusProc.running = false;
            _statusProc.running = true;
        }
    }

    // nmcli outputs TYPE:STATE:CONNECTION:DEVICE per line
    property var _statusProc: Process {
        command: ["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION,DEVICE", "device", "status"]
        stdout: StdioCollector {
            onStreamFinished: root._parseStatus(this.text)
        }
    }

    function _parseStatus(text) {
        const lines = text.trim().split("\n");
        // Prefer wifi, fall back to ethernet
        let best = null;
        for (const line of lines) {
            const parts = line.split(":");
            if (parts.length < 4) continue;
            const type  = parts[0].toLowerCase();
            const state = parts[1].toLowerCase();
            const conn  = parts[2];
            const dev   = parts[3];
            if (type !== "wifi" && type !== "ethernet") continue;
            if (state === "connected") {
                if (type === "wifi" || !best) {
                    best = { type, state, conn, dev };
                    if (type === "wifi") break; // wifi wins
                }
            } else if (!best) {
                best = { type, state, conn, dev };
            }
        }

        if (best) {
            _devType    = best.type;
            _state      = best.state;
            _connection = best.conn;
            _device     = best.dev;
        } else {
            _devType = ""; _state = ""; _connection = ""; _device = "";
        }

        // Fetch IP for wired, signal for wifi
        if (_state === "connected") {
            if (_devType === "ethernet") _fetchIp();
            else if (_devType === "wifi") _fetchSignal();
        } else {
            _ipAddress = "";
            _signal = 0;
        }
    }

    // --- IP address (wired) ---

    function _fetchIp() {
        _ipProc.running = false;
        _ipProc.command = ["sh", "-c",
            "ip -4 addr show dev " + _device +
            " 2>/dev/null | grep -oP 'inet \\K[^/]+' | head -1"
        ];
        _ipProc.running = true;
    }

    property var _ipProc: Process {
        stdout: StdioCollector {
            onStreamFinished: root._ipAddress = this.text.trim()
        }
    }

    // --- WAN IP address ---

    property var _wanTimer: Timer {
        interval: 60000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            _wanProc.running = false;
            _wanProc.running = true;
        }
    }

    property var _wanProc: Process {
        command: ["curl", "-s", "--max-time", "3", "ifconfig.me"]
        stdout: StdioCollector {
            onStreamFinished: root.wanAddress = this.text.trim()
        }
    }

    // --- Signal strength (wifi) ---

    function _fetchSignal() {
        _sigProc.running = false;
        _sigProc.command = ["nmcli", "-t", "-f", "ACTIVE,SIGNAL", "dev", "wifi"];
        _sigProc.running = true;
    }

    property var _sigProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n");
                for (const line of lines) {
                    const parts = line.split(":");
                    if (parts[0] === "yes") {
                        root._signal = parseInt(parts[1]) || 0;
                        return;
                    }
                }
            }
        }
    }
}
