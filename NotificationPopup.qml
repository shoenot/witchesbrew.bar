import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "."

PopupWindow {
    id: popup

    property var notifications: []

    color: "transparent"
    implicitWidth: 360
    implicitHeight: toastColumn.implicitHeight + 38

    visible: notifications.length > 0

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
            id: toastColumn
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            Repeater {
                model: popup.notifications

                delegate: Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: toastContent.implicitHeight + 16
                    implicitHeight: toastContent.implicitHeight + 16

                    ColumnLayout {
                        id: toastContent
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: modelData.summary || "Notification"
                                color: Config.colAccent
                                font { family: Config.fontFamily; pixelSize: Config.fontSize; bold: true }
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "\u2715"
                                color: dismissToastMouse.containsMouse ? Config.colFg : Config.colMuted
                                font { family: Config.fontFamily; pixelSize: Config.fontSize }
                                Behavior on color { ColorAnimation { duration: Config.animDurationFast } }
                                MouseArea {
                                    id: dismissToastMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: popup.dismissNotification(index)
                                }
                            }
                        }

                        Text {
                            visible: text !== ""
                            text: modelData.body || ""
                            color: Config.colFg
                            font { family: Config.fontFamily; pixelSize: 13 }
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }

                    // separator between toasts
                    Rectangle {
                        visible: index < popup.notifications.length - 1
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: Config.colWine
                    }

                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        onClicked: popup.dismissNotification(index)
                    }

                    Timer {
                        running: true
                        interval: modelData.timeout || 5000
                        onTriggered: popup.dismissNotification(index)
                    }
                }
            }
        }
    }

    function showNotification(summary, body, timeout) {
        let list = notifications.slice();
        list.push({ summary: summary, body: body, timeout: timeout > 0 ? timeout : 5000 });
        if (list.length > 3) list.shift();
        notifications = list;
    }

    function dismissNotification(idx) {
        let list = notifications.slice();
        if (idx >= 0 && idx < list.length) {
            list.splice(idx, 1);
            notifications = list;
        }
    }
}
