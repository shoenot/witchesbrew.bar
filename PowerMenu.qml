import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "."

PopupWindow {
    id: popup

    color: "transparent"
    implicitWidth: 150
    implicitHeight: menuCol.implicitHeight + 38

    Process { id: cmdRunner }

    function runCommand(cmd) {
        cmdRunner.command = ["sh", "-c", cmd];
        cmdRunner.running = true;
        popup.visible = false;
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
            id: menuCol
            anchors.fill: parent
            anchors.margins: 14
            spacing: 6

            Text {
                text: "POWER"
                color: Config.colAccent
                font { family: Config.fontFamily; pixelSize: 13; bold: true }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Config.colWine
            }

            Repeater {
                model: [
                    { icon: "\uf456", label: "lock",     cmd: "loginctl lock-session" },
                    { icon: "\udb80\udf43", label: "logout",   cmd: "hyprctl dispatch exit" },
                    { icon: "\udb81\udf09", label: "reboot",   cmd: "systemctl reboot" },
                    { icon: "\udb81\udc25", label: "shutdown", cmd: "systemctl poweroff" }
                ]

                delegate: Rectangle {
                    Layout.fillWidth: true
                    height: 20
                    radius: Config.popupRadius / 2
                    color: btnMouse.containsMouse ? Config.colSurface : "transparent"

                    Behavior on color { ColorAnimation { duration: Config.animDurationFast } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 12

                        Text {
                            text: modelData.icon
                            color: btnMouse.containsMouse ? Config.colAccent : Config.colWine
                            font { family: Config.fontFamily; pixelSize: 18 }
                            Behavior on color { ColorAnimation { duration: Config.animDurationFast } }
                        }

                        Text {
                            text: modelData.label
                            color: btnMouse.containsMouse ? Config.colFg : Config.colMuted
                            font { family: Config.fontFamily; pixelSize: Config.fontSize }
                            Layout.fillWidth: true
                            Behavior on color { ColorAnimation { duration: Config.animDurationFast } }
                        }
                    }

                    MouseArea {
                        id: btnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popup.runCommand(modelData.cmd)
                    }
                }
            }
        }
    }
}
