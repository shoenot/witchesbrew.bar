import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Bluetooth
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "."

PanelWindow {
    id: root
    WlrLayershell.namespace: "witches-brew-bar"

    // ── Per-monitor configuration (set by shell.qml) ────────────────────
    property string monitorName: ""
    property int    workspaceStart: 1
    property int    workspaceCount: 4
    property bool   isFull: true
    property var    notifServer: null

    screen: Quickshell.screens.find(s => s.name === monitorName)

    // ── Forward notification to the popup ────────────────────────────────
    function showNotification(summary, body, timeout) {
        notifPopup.showNotification(summary, body, timeout);
    }

    // ── Helpers (only used on full bars) ─────────────────────────────────
    NetworkStatus { id: networkStatus }
    VolumeControl { id: volumeControl }

    Process { id: nmLauncher;      command: [Config.networkManagerCmd] }
    Process { id: bluejayLauncher; command: [Config.bluetoothManagerCmd] }

    property bool anyPopupOpen: isFull && (volumePopup.visible || notifCenter.visible || powerMenu.visible || calendarPopup.visible)
    WlrLayershell.keyboardFocus: anyPopupOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    function closeAllPopups() {
        volumePopup.visible = false;
        notifCenter.visible = false;
        powerMenu.visible = false;
        calendarPopup.visible = false;
    }

    function togglePopup(popup) {
        let wasVisible = popup.visible;
        closeAllPopups();
        popup.visible = !wasVisible;
    }

    Connections {
        target: ToplevelManager
        enabled: root.anyPopupOpen
        function onActiveToplevelChanged() {
            root.closeAllPopups();
        }
    }

    // ── Bar geometry ─────────────────────────────────────────────────────
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    implicitHeight: Config.barHeight
    color: "transparent"

    // background
    Rectangle {
        anchors.fill: parent
        color: Config.colBg
    }

    // top border
    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 1
        color: Config.colBorder
    }

    // close popups on bar background click or Escape
    MouseArea {
        anchors.fill: parent
        visible: root.anyPopupOpen
        onClicked: root.closeAllPopups()
    }

    Item {
        anchors.fill: parent
        focus: root.anyPopupOpen
        Keys.onEscapePressed: root.closeAllPopups()
    }

    // ── Main row layout ──────────────────────────────────────────────────
    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: 8
        spacing: 10

        // workspaces
        Repeater {
            model: root.workspaceCount

            Rectangle {
                property int wsId: root.workspaceStart + index
                property bool isActive: Hyprland.focusedWorkspace?.id === wsId
                color: isActive ? Config.colAccent : "transparent"
                border.width: isActive ? 0 : 1
                border.color: Config.colAccent

                Behavior on color       { ColorAnimation  { duration: Config.animDuration; easing.type: Easing.OutCubic } }
                Behavior on width       { NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutCubic } }
                Behavior on border.width { NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutCubic } }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch("workspace " + wsId)
                }

                width: isActive ? 12 : 8
                height: 8
                radius: height / 2
                antialiasing: true

                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                Layout.preferredWidth: width
                Layout.preferredHeight: height
            }
        }

        // active window name
        Text {
            id: activeWindow
            color: Config.colAccent
            font {
                family: Config.fontFamily
                pixelSize: Config.fontSize
                bold: false
            }
            property bool onMonitor: Hyprland.focusedMonitor?.name === Screen.name
            property bool showDesktop: Hyprland.focusedWorkspace?.toplevels.values.length == 0 || ToplevelManager.activeToplevel == null
            text: onMonitor ? (showDesktop ? "Desktop" : (Hyprland.activeToplevel?.title ?? "")) : ""
            elide: Text.ElideRight
            Layout.maximumWidth: root.width * 0.3
            Layout.leftMargin: 15
        }

        // spacer
        Item { Layout.fillWidth: true }

        // system tray
        Row {
            spacing: 10
            Layout.rightMargin: 10
            Repeater {
                model: SystemTray.items
                delegate: Image {
                    source: modelData.icon
                    width: 16
                    height: 16
                    opacity: trayMouse.containsMouse ? 1.0 : 0.8

                    Behavior on opacity { NumberAnimation { duration: Config.animDurationFast } }

                    MouseArea {
                        id: trayMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.LeftButton) {
                                modelData.activate()
                            } else if (mouse.button === Qt.RightButton) {
                                let pos = mapToItem(null, mouse.x, mouse.y);
                                modelData.display(root, pos.x, pos.y)
                            }
                        }
                    }
                }
            }
        }

        // ── Full-bar-only widgets ────────────────────────────────────────

        // volume
        Item {
            id: volumeRow
            visible: root.isFull
            implicitWidth: volumeContent.implicitWidth
            implicitHeight: volumeContent.implicitHeight
            Layout.rightMargin: 10

            Row {
                id: volumeContent
                spacing: 5

                Text {
                    text: volumeControl.icon
                    color: volumeMouse.containsMouse ? Config.colAccent : Config.colFg
                    font { family: Config.fontFamily; pixelSize: Config.fontSize; bold: false }
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: Config.animDurationFast } }
                }

                Text {
                    text: Math.round(volumeControl.volume * 100) + "%"
                    color: volumeMouse.containsMouse ? Config.colAccent : Config.colFg
                    font { family: Config.fontFamily; pixelSize: Config.fontSize; bold: false }
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: Config.animDurationFast } }
                }
            }

            MouseArea {
                id: volumeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                onClicked: (mouse) => {
                    if (mouse.button === Qt.MiddleButton) {
                        volumeControl.toggleMute();
                    } else {
                        root.togglePopup(volumePopup);
                    }
                }
                onWheel: (wheel) => {
                    let delta = wheel.angleDelta.y > 0 ? 0.01 : -0.01;
                    volumeControl.setVolume(volumeControl.volume + delta);
                }
            }
        }

        // bluetooth
        Item {
            visible: root.isFull
            implicitWidth: btContent.implicitWidth
            implicitHeight: btContent.implicitHeight
            Layout.rightMargin: 10

            Row {
                id: btContent
                spacing: 8

                Text {
                    text: Bluetooth.defaultAdapter?.enabled ? "\udb80\udcaf" : "\udb80\udcb2"
                    color: Bluetooth.defaultAdapter?.enabled ? Config.colBTConnected : Config.colMuted
                    font { family: Config.fontFamily; pixelSize: Config.fontSize; bold: false }
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: Config.animDuration } }
                }

                Text {
                    visible: Bluetooth.defaultAdapter?.enabled && connectedDeviceName !== ""
                    text: connectedDeviceName
                    color: Config.colBTConnected
                    font { family: Config.fontFamily; pixelSize: Config.fontSize; bold: false }
                    anchors.verticalCenter: parent.verticalCenter

                    readonly property string connectedDeviceName: {
                        if (!Bluetooth.defaultAdapter) return "";
                        let device = Bluetooth.defaultAdapter.devices.values.find(d => d.connected);
                        return device ? device.name : "on";
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { bluejayLauncher.running = false; bluejayLauncher.running = true; }
            }
        }

        // network
        Item {
            id: networkRow
            visible: root.isFull
            implicitWidth: networkContent.implicitWidth
            implicitHeight: networkContent.implicitHeight
            Layout.rightMargin: 10

            Row {
                id: networkContent
                spacing: 5

                Text {
                    text: networkStatus.icon
                    color: networkStatus.iconColor
                    font { family: Config.fontFamily; pixelSize: Config.fontSize; bold: false }
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: Config.animDuration } }
                }

                Text {
                    text: networkStatus.displayText
                    color: Config.colNetConnected
                    font { family: Config.fontFamily; pixelSize: Config.fontSize; bold: false }
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: networkTooltip.visible = true
                onExited: networkTooltip.visible = false
                onClicked: { nmLauncher.running = false; nmLauncher.running = true; }
            }
        }

        // notification bell
        Item {
            id: notifRow
            visible: root.isFull
            implicitWidth: notifContent.implicitWidth
            implicitHeight: notifContent.implicitHeight
            Layout.rightMargin: 10

            property int notifCount: root.notifServer ? root.notifServer.trackedNotifications.count : 0

            Row {
                id: notifContent
                spacing: 3

                Text {
                    text: notifRow.notifCount > 0 ? "󰂞" : "󰂜"
                    color: notifRow.notifCount > 0 ? Config.colNotifActive : Config.colNotifInactive
                    font { family: Config.fontFamily; pixelSize: Config.fontSize; bold: false }
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: Config.animDuration } }
                }

                // unread badge
                Rectangle {
                    id: notifBadge
                    visible: notifRow.notifCount > 0
                    width: badgeText.implicitWidth + 6
                    height: 14
                    radius: 7
                    color: Config.colAccent
                    anchors.verticalCenter: parent.verticalCenter
                    scale: 1

                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                    Text {
                        id: badgeText
                        anchors.centerIn: parent
                        text: notifRow.notifCount > 99 ? "99+" : notifRow.notifCount
                        color: Config.colBg
                        font { family: Config.fontFamily; pixelSize: 9; bold: true }
                    }
                }
            }

            // pulse badge on count change
            onNotifCountChanged: {
                if (notifCount > 0) {
                    notifBadge.scale = 1.4;
                    badgePulseTimer.restart();
                }
            }

            Timer {
                id: badgePulseTimer
                interval: 200
                onTriggered: notifBadge.scale = 1
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.togglePopup(notifCenter)
            }
        }

        // power icon
        Text {
            id: powerIcon
            visible: root.isFull
            text: "󰚌"
            color: powerMouse.containsMouse ? Config.colPowerHover : Config.colPowerIdle
            font { family: Config.fontFamily; pixelSize: Config.fontSize; bold: false }

            Behavior on color { ColorAnimation { duration: Config.animDurationFast } }

            MouseArea {
                id: powerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.togglePopup(powerMenu)
            }
        }
    }

    // ── Centered clock ───────────────────────────────────────────────────
    Text {
        id: clock
        color: Config.colAccent
        font { family: Config.fontFamily; pixelSize: Config.fontSize; bold: false }
        text: Qt.formatDateTime(new Date(), Config.clockFormat)

        anchors.centerIn: parent

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: clock.text = Qt.formatDateTime(new Date(), Config.clockFormat)
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.isFull) {
                    root.togglePopup(calendarPopup);
                } else {
                    calendarPopup.visible = !calendarPopup.visible;
                }
            }
        }
    }

    // ── Popups ───────────────────────────────────────────────────────────

    VolumePopup {
        id: volumePopup
        visible: false
        anchor.item: volumeRow
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        anchor.adjustment: PopupAdjustment.Slide
        anchor.margins.bottom: 60
    }

    NotificationPopup {
        id: notifPopup
        anchor.item: notifRow
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        anchor.adjustment: PopupAdjustment.Slide
        anchor.margins.bottom: 60
    }

    NotificationCenter {
        id: notifCenter
        visible: false
        notificationModel: root.notifServer ? root.notifServer.trackedNotifications : null
        anchor.item: notifRow
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        anchor.adjustment: PopupAdjustment.Slide
        anchor.margins.bottom: 60
    }

    PowerMenu {
        id: powerMenu
        visible: false
        anchor.item: powerIcon
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        anchor.adjustment: PopupAdjustment.Slide
        anchor.margins.bottom: 60
    }

    CalendarPopup {
        id: calendarPopup
        visible: false
        anchor.item: clock
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        anchor.adjustment: PopupAdjustment.Slide
        anchor.margins.bottom: 60
    }

    // network tooltip
    PopupWindow {
        id: networkTooltip
        visible: false
        anchor.item: networkRow
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        anchor.adjustment: PopupAdjustment.Slide
        anchor.margins.bottom: 60
        color: "transparent"
        implicitWidth: tooltipContent.implicitWidth + 28
        implicitHeight: tooltipContent.implicitHeight + 20

        Rectangle {
            id: tooltipRect
            anchors.fill: parent
            anchors.bottomMargin: 10
            color: Config.colBg
            border.width: 1
            border.color: Config.colBorder
            radius: Config.popupRadius

            opacity: 0
            transform: Translate { id: tooltipSlide; y: 8 }

            states: State {
                name: "open"; when: networkTooltip.visible
                PropertyChanges { target: tooltipRect; opacity: 1 }
                PropertyChanges { target: tooltipSlide; y: 0 }
            }
            transitions: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; duration: Config.animDurationFast; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "y"; duration: Config.animDurationFast; easing.type: Easing.OutCubic }
                }
            }

            Column {
                id: tooltipContent
                anchors.centerIn: parent
                spacing: 4

                Text {
                    text: "Interface: " + networkStatus.interfaceName
                    color: Config.colFg
                    font { family: Config.fontFamily; pixelSize: 13 }
                }

                Text {
                    text: "WAN: " + (networkStatus.wanAddress || "fetching...")
                    color: Config.colFg
                    font { family: Config.fontFamily; pixelSize: 13 }
                }
            }
        }
    }
}
