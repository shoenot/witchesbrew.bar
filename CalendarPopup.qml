import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "."

PopupWindow {
    id: popup

    property int displayMonth: new Date().getMonth()
    property int displayYear: new Date().getFullYear()

    color: "transparent"
    implicitWidth: 280
    implicitHeight: calendarCol.implicitHeight + 34

    readonly property var dayNames: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    function daysInMonth(year, month) {
        return new Date(year, month + 1, 0).getDate();
    }

    // 0=Mon, 6=Sun (ISO)
    function firstDayOfWeek(year, month) {
        let d = new Date(year, month, 1).getDay();
        return (d + 6) % 7;
    }

    function generateCalendarDays() {
        let days = [];
        let totalDays = daysInMonth(displayYear, displayMonth);
        let startDay = firstDayOfWeek(displayYear, displayMonth);

        // previous month's trailing days
        let prevMonth = displayMonth === 0 ? 11 : displayMonth - 1;
        let prevYear = displayMonth === 0 ? displayYear - 1 : displayYear;
        let prevDays = daysInMonth(prevYear, prevMonth);
        for (let i = startDay - 1; i >= 0; i--) {
            days.push({ day: prevDays - i, current: false, today: false });
        }

        // current month days
        let now = new Date();
        for (let d = 1; d <= totalDays; d++) {
            let isToday = (d === now.getDate() && displayMonth === now.getMonth() && displayYear === now.getFullYear());
            days.push({ day: d, current: true, today: isToday });
        }

        // next month leading days to fill grid (6 rows max)
        let remaining = 42 - days.length;
        for (let i = 1; i <= remaining; i++) {
            days.push({ day: i, current: false, today: false });
        }

        return days;
    }

    property var calendarDays: generateCalendarDays()

    onDisplayMonthChanged: calendarDays = generateCalendarDays()
    onDisplayYearChanged: calendarDays = generateCalendarDays()

    function prevMonth() {
        if (displayMonth === 0) {
            displayMonth = 11;
            displayYear--;
        } else {
            displayMonth--;
        }
    }

    function nextMonth() {
        if (displayMonth === 11) {
            displayMonth = 0;
            displayYear++;
        } else {
            displayMonth++;
        }
    }

    readonly property var monthNames: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]

    onVisibleChanged: {
        if (visible) {
            let now = new Date();
            displayMonth = now.getMonth();
            displayYear = now.getFullYear();
        }
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
            id: calendarCol
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // header: < Month Year >
            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    text: "\u25C0"
                    color: prevMouse.containsMouse ? Config.colFg : Config.colAccent
                    font { family: Config.fontFamily; pixelSize: 13 }
                    Behavior on color { ColorAnimation { duration: Config.animDurationFast } }
                    MouseArea {
                        id: prevMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popup.prevMonth()
                    }
                    Layout.preferredWidth: 24
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: popup.monthNames[popup.displayMonth] + " " + popup.displayYear
                    color: Config.colAccent
                    font { family: Config.fontFamily; pixelSize: Config.fontSize; bold: true }
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }

                Text {
                    text: "\u25B6"
                    color: nextMouse.containsMouse ? Config.colFg : Config.colAccent
                    font { family: Config.fontFamily; pixelSize: 13 }
                    Behavior on color { ColorAnimation { duration: Config.animDurationFast } }
                    MouseArea {
                        id: nextMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popup.nextMonth()
                    }
                    Layout.preferredWidth: 24
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            // day name headers
            Row {
                Layout.fillWidth: true
                spacing: 0

                Repeater {
                    model: popup.dayNames
                    Text {
                        width: 36
                        text: modelData
                        color: Config.colMuted
                        font { family: Config.fontFamily; pixelSize: 11 }
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // calendar grid
            Grid {
                Layout.fillWidth: true
                columns: 7
                spacing: 0

                Repeater {
                    model: popup.calendarDays

                    Rectangle {
                        width: 36
                        height: 28
                        radius: Config.popupRadius / 2
                        color: {
                            if (modelData.today) return Config.colAccent
                            if (dayHover.containsMouse && modelData.current) return Config.colSurface
                            return "transparent"
                        }

                        Behavior on color { ColorAnimation { duration: Config.animDurationFast } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.day
                            color: {
                                if (modelData.today) return Config.colBg
                                if (modelData.current) return Config.colFg
                                return Config.colMuted
                            }
                            font {
                                family: Config.fontFamily
                                pixelSize: 12
                                bold: modelData.today
                            }
                        }

                        MouseArea {
                            id: dayHover
                            anchors.fill: parent
                            hoverEnabled: true
                        }
                    }
                }
            }
        }
    }
}
