import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import "."

PopupWindow {
    id: popup

    color: "transparent"
    implicitWidth: 300
    implicitHeight: contentCol.implicitHeight + 38

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
            spacing: 10

            Text {
                text: "AUDIO OUTPUT"
                color: Config.colAccent
                font { family: Config.fontFamily; pixelSize: 15; bold: true }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Config.colWine
            }

            Repeater {
                model: {
                    let sinks = [];
                    if (Pipewire.nodes) {
                        let vals = Pipewire.nodes.values;
                        for (let i = 0; i < vals.length; i++) {
                            let n = vals[i];
                            if (!n.isStream && n.isSink) sinks.push(n);
                        }
                    }
                    return sinks;
                }

                delegate: Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: Config.popupRadius / 2
                    color: sinkMouse.containsMouse ? Config.colSurface : "transparent"

                    Behavior on color { ColorAnimation { duration: Config.animDurationFast } }

                    property bool isDefault: modelData === Pipewire.defaultAudioSink

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Rectangle {
                            width: 12
                            height: 12
                            radius: 2
                            color: isDefault ? Config.colAccent : "transparent"
                            border.width: 1.5
                            border.color: isDefault ? Config.colAccent : Config.colMuted

                            Behavior on color        { ColorAnimation  { duration: Config.animDuration } }
                            Behavior on border.color { ColorAnimation  { duration: Config.animDuration } }
                        }

                        Text {
                            text: modelData.nickname || modelData.description || modelData.name
                            color: isDefault ? Config.colAccent : Config.colFg
                            font { family: Config.fontFamily; pixelSize: Config.fontSize }
                            elide: Text.ElideRight
                            Layout.fillWidth: true

                            Behavior on color { ColorAnimation { duration: Config.animDuration } }
                        }
                    }

                    MouseArea {
                        id: sinkMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Pipewire.preferredDefaultAudioSink = modelData;
                        }
                    }
                }
            }
        }
    }
}
