import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
    id: root
    moduleName: "wizwam.omasync"
    ipcTarget: "wizwam.omasync"
    manageIpc: false

    property string daemonState: "offline"
    property string daemonRole: "host"
    property int activeCopies: 0

    readonly property color foreground: bar ? bar.barForeground : Color.foreground
    readonly property color dim: Qt.darker(foreground, 1.45)
    readonly property bool live: daemonState === "idle" || daemonState === "copying"

    implicitWidth: chip.implicitWidth
    implicitHeight: chip.implicitHeight

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
    }

    Process {
        id: statusProc
        command: ["omasyncd", "status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.parseStatus(this.text)
        }
    }

    Timer {
        interval: 2500
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Rectangle {
        id: chip
        implicitWidth: row.implicitWidth + 14
        implicitHeight: 22
        radius: 6
        color: "transparent"

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 6

            Rectangle {
                width: 6
                height: 6
                radius: 3
                anchors.verticalCenter: parent.verticalCenter
                color: root.live ? (bar ? bar.foreground : Color.foreground) : root.dim
            }

            Text {
                text: root.daemonState === "copying" ? (root.activeCopies + " copying") : "OmaSync"
                color: root.live ? root.foreground : root.dim
                font.family: bar ? bar.fontFamily : Style.font.family
                font.pixelSize: 12
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function (mouse) {
                if (mouse.button === Qt.RightButton)
                    root.refresh()
                else
                    root.toggle()
            }
        }
    }
}
