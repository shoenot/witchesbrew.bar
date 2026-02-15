import Quickshell
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "."

PopupWindow {
    id: popup

    color: "transparent"
    implicitWidth: 280
    implicitHeight: contentCol.implicitHeight + 38

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: adapter ? adapter.devices.values : []

    // Separate connected and paired-but-disconnected devices
    readonly property var connectedDevices: {
        let result = [];
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].connected) result.push(devices[i]);
        }
        return result;
    }

    readonly property var pairedDevices: {
        let result = [];
        for (let i = 0; i < devices.length; i++) {
            if (!devices[i].connected) result.push(devices[i]);
        }
        return result;
    }

    Process { id: btLauncher; command: [Config.bluetoothManagerCmd] }

    // Toggle adapter power via bluetoothctl
    Process { id: btToggle }

    function toggleAdapter() {
        let enabled = adapter?.enabled ?? false;
        btToggle.command = ["bluetoothctl", "power", enabled ? "off" : "on"];
        btToggle.running = true;
    }

    // Connect/disconnect via bluetoothctl
    Process { id: btConnect }

    function connectDevice(address) {
        btConnect.command = ["bluetoothctl", "connect", address];
        btConnect.running = true;
    }

    function disconnectDevice(address) {
        btConnect.command = ["bluetoothctl", "disconnect", address];
        btConnect.running = true;
    }

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

            // ── Header with toggle ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "BLUETOOTH"
                    color: Config.colAccent
                    font { family: Config.fontFamily; pixelSize: 15; bold: true }
                    Layout.fillWidth: true
                }

                // Power toggle
                Rectangle {
                    width: 36
                    height: 18
                    radius: 9
                    color: popup.adapter?.enabled ? Config.colBTConnected : Config.colMuted

                    Behavior on color { ColorAnimation { duration: Config.animDuration } }

                    Rectangle {
                        width: 14
                        height: 14
                        radius: 7
                        color: Config.colFg
                        y: 2
                        x: popup.adapter?.enabled ? parent.width - width - 2 : 2

                        Behavior on x { NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popup.toggleAdapter()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Config.colWine
            }

            // ── Disabled message ──
            Text {
                visible: !(popup.adapter?.enabled)
                text: "Bluetooth is off"
                color: Config.colMuted
                font { family: Config.fontFamily; pixelSize: Config.fontSize; italic: true }
            }

            // ── Connected devices ──
            Text {
                visible: popup.adapter?.enabled && popup.connectedDevices.length > 0
                text: "CONNECTED"
                color: Config.colMuted
                font { family: Config.fontFamily; pixelSize: 11; bold: true }
                Layout.topMargin: 2
            }

            Repeater {
                model: popup.adapter?.enabled ? popup.connectedDevices : []

                delegate: Rectangle {
                    Layout.fillWidth: true
                    height: 34
                    radius: Config.popupRadius / 2
                    color: connDevMouse.containsMouse ? Config.colSurface : "transparent"

                    Behavior on color { ColorAnimation { duration: Config.animDurationFast } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Text {
                            text: "\udb80\udcaf"
                            color: Config.colBTConnected
                            font { family: Config.fontFamily; pixelSize: Config.fontSize }
                        }

                        Text {
                            text: modelData.name || "Unknown Device"
                            color: Config.colBTConnected
                            font { family: Config.fontFamily; pixelSize: Config.fontSize; bold: true }
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: "✓"
                            color: Config.colBTConnected
                            font { family: Config.fontFamily; pixelSize: 12; bold: true }
                        }
                    }

                    MouseArea {
                        id: connDevMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popup.disconnectDevice(modelData.address)
                    }
                }
            }

            // ── Paired devices ──
            Text {
                visible: popup.adapter?.enabled && popup.pairedDevices.length > 0
                text: "PAIRED"
                color: Config.colMuted
                font { family: Config.fontFamily; pixelSize: 11; bold: true }
                Layout.topMargin: 2
            }

            Repeater {
                model: popup.adapter?.enabled ? popup.pairedDevices : []

                delegate: Rectangle {
                    Layout.fillWidth: true
                    height: 34
                    radius: Config.popupRadius / 2
                    color: pairedDevMouse.containsMouse ? Config.colSurface : "transparent"

                    Behavior on color { ColorAnimation { duration: Config.animDurationFast } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Text {
                            text: "\udb80\udcb2"
                            color: Config.colMuted
                            font { family: Config.fontFamily; pixelSize: Config.fontSize }
                        }

                        Text {
                            text: modelData.name || "Unknown Device"
                            color: Config.colFg
                            font { family: Config.fontFamily; pixelSize: Config.fontSize }
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        id: pairedDevMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popup.connectDevice(modelData.address)
                    }
                }
            }

            // ── Empty state ──
            Text {
                visible: popup.adapter?.enabled && popup.devices.length === 0
                text: "No paired devices"
                color: Config.colMuted
                font { family: Config.fontFamily; pixelSize: Config.fontSize; italic: true }
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
                color: btSettingsMouse.containsMouse ? Config.colSurface : "transparent"

                Behavior on color { ColorAnimation { duration: Config.animDurationFast } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    Text {
                        text: "󰒓"
                        color: btSettingsMouse.containsMouse ? Config.colAccent : Config.colMuted
                        font { family: Config.fontFamily; pixelSize: 16 }
                        Behavior on color { ColorAnimation { duration: Config.animDurationFast } }
                    }

                    Text {
                        text: "Bluetooth Settings"
                        color: btSettingsMouse.containsMouse ? Config.colFg : Config.colMuted
                        font { family: Config.fontFamily; pixelSize: Config.fontSize }
                        Layout.fillWidth: true
                        Behavior on color { ColorAnimation { duration: Config.animDurationFast } }
                    }
                }

                MouseArea {
                    id: btSettingsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        btLauncher.running = false;
                        btLauncher.running = true;
                        popup.visible = false;
                    }
                }
            }
        }
    }
}
