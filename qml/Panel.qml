import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Rectangle {
    id: panel
    width: 380
    height: 420
    radius: 16
    color: bar ? bar.background : Color.background
    border.width: 1
    border.color: bar ? bar.border : Color.border

    property string statusLine: "omasyncd · starting"

    function parseStatus(text) {
        const t = (text || "").trim()
        statusLine = t.length ? t : "omasyncd offline — run install.sh"
    }

    Process {
        id: statusProc
        command: ["omasyncd", "status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: panel.parseStatus(this.text)
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12

        Text {
            text: "OmaSync"
            color: bar ? bar.foreground : Color.foreground
            font.family: bar ? bar.fontFamily : Style.font.family
            font.pixelSize: 22
            font.weight: Font.DemiBold
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Carry folders without the internet. Host mirrors to your phone, Bluetooth hands off at Dad's, hotspot lands files on his Omarchy."
            color: bar ? bar.foreground : Color.foreground
            opacity: 0.7
            font.pixelSize: 13
        }

        Text {
            width: parent.width
            wrapMode: Text.WrapAnywhere
            text: panel.statusLine
            color: bar ? bar.foreground : Color.foreground
            font.family: "IBM Plex Mono, monospace"
            font.pixelSize: 11
            opacity: 0.85
        }
    }
}
