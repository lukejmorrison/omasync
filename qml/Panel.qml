import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Dropdown body: daemon chip + the live OmaSync app (omasync.grok.me).
Item {
    id: panel
    property var bar: null
    property string appUrl: "https://omasync.grok.me/"
    property string daemonState: "offline"
    property string daemonRole: "host"
    property string statusLine: ""

    readonly property color foreground: bar ? bar.foreground : Color.foreground
    readonly property color dim: Qt.darker(foreground, 1.45)
    readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
    readonly property bool webOk: webLoader.status === Loader.Ready
    readonly property bool live: daemonState === "idle" || daemonState === "copying"

    function parseStatus(text) {
        const t = (text || "").trim()
        statusLine = t.length ? t : "omasyncd offline"
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
        if (webLoader.item && webLoader.item.reload)
            webLoader.item.reload()
        else if (webLoader.item && webLoader.item.url)
            webLoader.item.url = panel.appUrl
    }

    function openAppWindow() {
        openProc.running = false
        openProc.running = true
    }

    Process {
        id: statusProc
        command: ["bash", "-lc", "omasyncd status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: panel.parseStatus(this.text)
        }
    }

    Process {
        id: openProc
        running: false
        command: ["bash", "-lc", "omarchy-launch-webapp '" + panel.appUrl + "' 2>/dev/null || omarchy-launch-browser '" + panel.appUrl + "' 2>/dev/null || xdg-open '" + panel.appUrl + "'"]
    }

    Column {
        anchors.fill: parent
        anchors.margins: Style.space ? Style.space(14) : 14
        spacing: Style.space ? Style.space(10) : 10

        Item {
            width: parent.width
            height: Math.max(heroRow.height, 28)

            Row {
                id: heroRow
                spacing: 10
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                OmaSyncIcon {
                    iconSize: 22
                    color: panel.foreground
                    live: panel.live
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    spacing: 2
                    Text {
                        text: "OmaSync"
                        color: panel.foreground
                        font.family: panel.fontFamily
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: panel.daemonRole + " · " + panel.daemonState
                        color: panel.dim
                        font.family: panel.fontFamily
                        font.pixelSize: 11
                    }
                }
            }

            Rectangle {
                id: openBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: openLabel.implicitWidth + 16
                implicitHeight: 26
                radius: 6
                color: "transparent"
                border.width: 1
                border.color: panel.dim

                Text {
                    id: openLabel
                    anchors.centerIn: parent
                    text: "Open in window"
                    color: panel.foreground
                    font.family: panel.fontFamily
                    font.pixelSize: 11
                }

                MouseArea {
                    id: openHover
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: panel.openAppWindow()
                    onEntered: openBtn.border.color = panel.foreground
                    onExited: openBtn.border.color = panel.dim
                }
            }
        }

        Rectangle {
            width: parent.width
            height: parent.height - heroRow.height - (Style.space ? Style.space(10) : 10)
            radius: 10
            color: "#0c0d0b"
            border.width: 1
            border.color: panel.dim
            clip: true

            Loader {
                id: webLoader
                anchors.fill: parent
                anchors.margins: 1
                source: "AppWebView.qml"
                active: true
                onLoaded: {
                    if (item) {
                        if ("url" in item)
                            item.url = panel.appUrl
                    }
                }
            }

            Column {
                visible: !panel.webOk
                anchors.centerIn: parent
                width: parent.width - 48
                spacing: 12

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: "OmaSync app"
                    color: panel.foreground
                    font.family: panel.fontFamily
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: panel.appUrl
                    color: panel.dim
                    font.family: "IBM Plex Mono, monospace"
                    font.pixelSize: 12
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: "Install qt6-webengine to embed the app here, or open it in a window."
                    color: panel.foreground
                    opacity: 0.75
                    font.family: panel.fontFamily
                    font.pixelSize: 13
                    visible: !panel.webOk
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    implicitWidth: launchLabel.implicitWidth + 24
                    implicitHeight: 32
                    radius: 8
                    color: panel.foreground

                    Text {
                        id: launchLabel
                        anchors.centerIn: parent
                        text: "Open OmaSync"
                        color: "#0c0d0b"
                        font.family: panel.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.openAppWindow()
                    }
                }
            }
        }
    }
}
