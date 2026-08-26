import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Icon-only chip. Hover = alt text. Click = dropdown with omasync.grok.me.
Panel {
    id: root
    moduleName: "wizwam.omasync"
    ipcTarget: "wizwam.omasync"
    manageIpc: false

    property string daemonState: "offline"
    property string daemonRole: "host"
    property string appUrl: "https://omasync.grok.me/"

    readonly property color foreground: bar ? bar.foreground : Color.foreground
    readonly property color dim: Qt.darker(foreground, 1.45)
    readonly property bool live: daemonState === "idle" || daemonState === "copying"
    readonly property string altText: {
        if (daemonState === "copying")
            return "OmaSync — copying"
        if (live)
            return "OmaSync — carry folders without the internet"
        return "OmaSync — daemon offline"
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    function parseStatus(text) {
        const t = (text || "").trim()
        if (!t) {
            daemonState = "offline"
            return
        }
        const roleMatch = t.match(/"role"\s*:\s*"([^"]+)"/)
        const stateMatch = t.match(/"state"\s*:\s*"([^"]+)"/)
        if (roleMatch)
            daemonRole = roleMatch[1]
        if (stateMatch)
            daemonState = stateMatch[1]
        else if (t.indexOf("\"ok\":true") !== -1)
            daemonState = "idle"
    }

    function refresh() {
        statusProc.running = false
        statusProc.running = true
        if (bodyLoader.item && bodyLoader.item.refresh)
            bodyLoader.item.refresh()
    }

    function openAppWindow() {
        openProc.running = false
        openProc.running = true
    }

    onOpenedChanged: {
        if (opened) {
            refresh()
            if (button.hideOwnTooltip)
                button.hideOwnTooltip()
            Qt.callLater(function () {
                if (keyCatcher)
                    keyCatcher.forceActiveFocus()
            })
        }
    }

    Process {
        id: statusProc
        command: ["bash", "-lc", "omasyncd status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.parseStatus(this.text)
        }
    }

    Timer {
        interval: 2500
        running: true
        repeat: true
        onTriggered: {
            statusProc.running = false
            statusProc.running = true
        }
    }

    Process {
        id: openProc
        running: false
        command: ["bash", "-lc", "omarchy-launch-webapp '" + root.appUrl + "' 2>/dev/null || omarchy-launch-browser '" + root.appUrl + "' 2>/dev/null || xdg-open '" + root.appUrl + "'"]
    }

    IpcHandler {
        target: root.ipcTarget
        function open(): void { root.open() }
        function close(): void { root.close() }
        function show(): void { root.open() }
        function hide(): void { root.close() }
        function toggle(): void { root.toggle() }
        function refresh(): string { root.refresh(); return "ok" }
        function status(): string { return root.daemonRole + " " + root.daemonState }
    }

    BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        active: root.daemonState === "copying"
        tooltipText: root.altText
        iconComponent: Component {
            Item {
                OmaSyncIcon {
                    anchors.centerIn: parent
                    iconSize: Style.space ? Style.space(12) : 12
                    color: root.live ? root.foreground : root.dim
                    live: root.live
                }
            }
        }
        onPressed: function (buttonCode) {
            if (buttonCode === Qt.RightButton)
                root.refresh()
            else if (buttonCode === Qt.MiddleButton)
                root.openAppWindow()
            else
                root.toggle()
        }
    }

    KeyboardPanel {
        id: panel
        anchorItem: button
        owner: root
        bar: root.bar
        open: root.opened
        focusTarget: keyCatcher
        contentWidth: panel.fittedContentWidth(Style.space ? Style.space(720) : 720)
        contentHeight: panel.fittedContentHeight(Style.space ? Style.space(560) : 560, Style.space ? Style.space(640) : 640)

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onCloseRequested: root.close()
            onTabRequested: function (direction) {
                if (root.switchPanel)
                    root.switchPanel(direction)
                else if (root.bar && typeof root.bar.switchPanelFrom === "function")
                    root.bar.switchPanelFrom(root, direction)
            }
            onTextKey: function (t) {
                if (t === "o" || t === "O")
                    root.openAppWindow()
                else if (t === "r" || t === "R")
                    root.refresh()
            }

            Loader {
                id: bodyLoader
                anchors.fill: parent
                source: "Panel.qml"
                onLoaded: {
                    if (item) {
                        item.bar = root.bar
                        item.appUrl = root.appUrl
                        if (item.refresh)
                            item.refresh()
                    }
                }
            }
        }
    }
}
