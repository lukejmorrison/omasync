import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Icon-only chip. Green pulse = folders waiting. Click = accept picker.
Panel {
    id: root
    moduleName: "wizwam.omasync"
    ipcTarget: "wizwam.omasync"
    manageIpc: false

    property string daemonState: "offline"
    property string daemonRole: "host"
    property string appUrl: "https://omasync.grok.me/"
    property int waitingCount: 0
    property int waitingFiles: 0
    property var waitingNames: []
    property string statusJson: ""

    readonly property color foreground: bar ? bar.foreground : Color.foreground
    readonly property color dim: Qt.darker(foreground, 1.45)
    readonly property bool live: daemonState === "idle" || daemonState === "copying" || daemonState === "waiting"
    readonly property bool waiting: waitingCount > 0
    readonly property string altText: {
        if (waiting) {
            const names = waitingNames.join(", ")
            if (waitingCount === 1)
                return "Files waiting — you have a folder called " + names + ". Click to accept."
            return "Files waiting — " + names + ". Click to choose which files."
        }
        if (daemonState === "copying")
            return "OmaSync — copying"
        if (live)
            return "OmaSync — carry folders without the internet"
        return "OmaSync — daemon offline"
    }

    readonly property int glyph: Style.space ? Style.space(14) : 14
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    function parseStatus(text) {
        const t = (text || "").trim()
        if (!t)
            return
        statusJson = t
        try {
            const j = JSON.parse(t)
            daemonRole = j.role || daemonRole
            daemonState = j.state || (j.ok ? "idle" : "offline")
            waitingCount = j.waitingCount || 0
            waitingFiles = j.waitingFiles || 0
            waitingNames = j.waitingNames || []
            if (bodyLoader.item && bodyLoader.item.applyStatus)
                bodyLoader.item.applyStatus(j)
            return
        } catch (e) {
            const roleMatch = t.match(/"role"\s*:\s*"([^"]+)"/)
            const stateMatch = t.match(/"state"\s*:\s*"([^"]+)"/)
            if (roleMatch)
                daemonRole = roleMatch[1]
            if (stateMatch)
                daemonState = stateMatch[1]
        }
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
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            if (!statusProc.running)
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
        active: false
        tooltipText: root.altText
        iconComponent: Component {
            OmaSyncIcon {
                iconSize: root.glyph
                color: root.live ? root.foreground : root.dim
                live: root.live
                waiting: root.waiting
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
        contentWidth: panel.fittedContentWidth(Style.space ? Style.space(420) : 420)
        contentHeight: panel.fittedContentHeight(Style.space ? Style.space(520) : 520, Style.space ? Style.space(620) : 620)

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
                        if (root.statusJson && item.applyRaw)
                            item.applyRaw(root.statusJson)
                        else if (item.refresh)
                            item.refresh()
                    }
                }
            }
        }
    }
}
