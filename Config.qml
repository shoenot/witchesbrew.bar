pragma Singleton
import QtQuick

QtObject {
    // ── Monitor definitions ──────────────────────────────────────────────
    // Each entry spawns a bar on that monitor.
    //   name           – output name from `hyprctl monitors` (e.g. "eDP-1", "HDMI-A-1")
    //   workspaceStart – first workspace number assigned to this monitor
    //   workspaceCount – how many workspace dots to show
    //   full           – true  = show volume, bluetooth, network, notifications, power menu
    //                    false = minimal bar (workspaces, window title, tray, clock)
    readonly property var monitors: [
        { name: "eDP-1",    workspaceStart: 1, workspaceCount: 4, full: true  },
        { name: "HDMI-A-1", workspaceStart: 5, workspaceCount: 4, full: false }
    ]

    // ── Colors ───────────────────────────────────────────────────────────
    readonly property color colBg:              "#f0181015"
    readonly property color colFg:              "#e0ddd8"
    readonly property color colBorder:          "#a68295"
    readonly property color colMuted:           "#7a7872"
    readonly property color colAccent:          "#b394c9"
    readonly property color colSurface:         "#2a1f26"
    readonly property color colWine:            "#8b5a6b"
    readonly property color colBTConnected:     "#8194a6"
    readonly property color colBTNotConnected:  "#da9188"
    readonly property color colNetConnected:    "#88b5aa"
    readonly property color colNetConnecting:   "#f1fa8c"
    readonly property color colNetNotConnected: "#da9188"
    readonly property color colNotifActive:     "#da9188"
    readonly property color colNotifInactive:   "#8b5a6b"
    readonly property color colPowerHover:      "#da9188"
    readonly property color colPowerIdle:       "#8b5a6b"

    // ── Font ─────────────────────────────────────────────────────────────
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int    fontSize:   14
    readonly property int    fontWeight: 300

    // ── Bar geometry ─────────────────────────────────────────────────────
    readonly property int barHeight: 26

    // ── Clock ────────────────────────────────────────────────────────────
    readonly property string clockFormat: "ddd yyyy-MM-dd HH:mm:ss"

    // ── Animation ────────────────────────────────────────────────────────
    readonly property int animDuration:      150   // ms – general transition speed
    readonly property int animDurationFast:  100   // ms – hover highlights
    readonly property int animDurationSlow:  250   // ms – popups, larger motions

    // ── Popup geometry ───────────────────────────────────────────────────
    readonly property int popupRadius: 6

    // ── External launchers ───────────────────────────────────────────────
    readonly property string networkManagerCmd:   "nm-connection-editor"
    readonly property string bluetoothManagerCmd: "bluejay"
}
