import Quickshell.Services.Pipewire
import Quickshell.Io
import QtQuick

QtObject {
    id: root

    readonly property var defaultSink: Pipewire.defaultAudioSink ?? null

    property real volume: 0.0
    property bool muted: false

    readonly property string sinkName: {
        if (!defaultSink) return "Unknown";
        if (defaultSink.nickname !== "") return defaultSink.nickname;
        if (defaultSink.description !== "") return defaultSink.description;
        return defaultSink.name;
    }

    readonly property string icon: {
        if (muted) return "\udb81\udd5f" // 󰝟
        if (volume > 0.66) return "\udb81\udd7e" // 󰕾
        if (volume > 0.33) return "\udb81\udd80" // 󰖀
        return "\udb81\udd7f" // 󰕿
    }

    function setVolume(val) {
        val = Math.max(0.0, Math.min(1.0, val));
        volume = val; // update immediately for responsiveness
        _setProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", val.toFixed(2)];
        _setProc.running = true;
    }

    function toggleMute() {
        muted = !muted; // update immediately
        _muteProc.running = false;
        _muteProc.running = true;
    }

    // poll volume
    property var _pollTimer: Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root._poll()
    }

    function _poll() {
        _getProc.running = false;
        _getProc.running = true;
    }

    // wpctl get-volume outputs: "Volume: 0.50" or "Volume: 0.50 [MUTED]"
    property var _getProc: Process {
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                let text = this.text.trim();
                let match = text.match(/Volume:\s+([\d.]+)/);
                if (match) root.volume = parseFloat(match[1]);
                root.muted = text.indexOf("[MUTED]") !== -1;
            }
        }
    }

    property var _setProc: Process {
        onRunningChanged: if (!running) root._poll()
    }
    property var _muteProc: Process {
        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
        onRunningChanged: if (!running) root._poll()
    }
}
