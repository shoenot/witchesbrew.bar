import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import "."

PopupWindow {
    id: popup

    property var notificationModel: null

    color: "transparent"
    implicitWidth: 380
    implicitHeight: 430

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
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "NOTIFICATIONS"
                    color: Config.colAccent
                    font { family: Config.fontFamily; pixelSize: 15; bold: true }
                    Layout.fillWidth: true
                }

                Text {
                    text: "CLEAR ALL"
                    color: clearAllMouse.containsMouse ? Config.colAccent : Config.colMuted
                    font { family: Config.fontFamily; pixelSize: 13 }
                    Behavior on color { ColorAnimation { duration: Config.animDurationFast } }
                    MouseArea {
                        id: clearAllMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!popup.notificationModel) return;
                            let vals = popup.notificationModel.values;
                            for (let i = vals.length - 1; i >= 0; i--) {
                                vals[i].tracked = false;
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Config.colWine
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: historyCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: historyCol
                    width: parent.width
                    spacing: 8

                    Text {
                        visible: !popup.notificationModel || popup.notificationModel.count === 0
                        text: "No notifications"
                        color: Config.colMuted
                        font { family: Config.fontFamily; pixelSize: Config.fontSize }
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 20
                    }

                    Repeater {
                        model: popup.notificationModel

                        delegate: Item {
                            Layout.fillWidth: true
                            implicitHeight: entryContent.implicitHeight + 16

                            ColumnLayout {
                                id: entryContent
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: modelData.appName || modelData.summary
                                        color: Config.colAccent
                                        font { family: Config.fontFamily; pixelSize: 13; bold: true }
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: "\u2715"
                                        color: dismissMouse.containsMouse ? Config.colFg : Config.colMuted
                                        font { family: Config.fontFamily; pixelSize: 13 }
                                        Behavior on color { ColorAnimation { duration: Config.animDurationFast } }
                                        MouseArea {
                                            id: dismissMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: modelData.tracked = false
                                        }
                                    }
                                }

                                Text {
                                    visible: modelData.appName !== "" && modelData.summary !== ""
                                    text: modelData.summary
                                    color: Config.colFg
                                    font { family: Config.fontFamily; pixelSize: 13; bold: true }
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    visible: modelData.body !== ""
                                    text: modelData.body
                                    color: Config.colFg
                                    font { family: Config.fontFamily; pixelSize: 13 }
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                }
                            }

                            // separator
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 1
                                color: Config.colWine
                                opacity: 0.5
                            }
                        }
                    }
                }
            }
        }
    }
}
