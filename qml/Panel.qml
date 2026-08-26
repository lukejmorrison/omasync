import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Dropdown: folders waiting, file picker, accept.
Item {
    id: panel
    property var bar: null
    property string appUrl: "https://omasync.grok.me/"
    property string daemonState: "offline"
    property string daemonRole: "host"
    property int waitingCount: 0
    property string destination: "~/Incoming/OmaSync"
    property var offers: []

    readonly property color foreground: bar ? bar.foreground : Color.foreground
    readonly property color dim: Qt.darker(foreground, 1.45)
    readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
    readonly property bool waiting: waitingCount > 0
    readonly property color green: "#4ade80"

    function applyRaw(text) {
        try {
            applyStatus(JSON.parse((text || "").trim()))
        } catch (e) {
            refresh()
        }
    }

    function applyStatus(j) {
        if (!j)
            return
        daemonRole = j.role || daemonRole
        daemonState = j.state || daemonState
        waitingCount = j.waitingCount || 0
        destination = j.destination || destination
        offers = j.waiting || []
        rebuildModels()
    }

    function rebuildModels() {
        offerModel.clear()
        fileModel.clear()
        for (let i = 0; i < offers.length; i++) {
            const o = offers[i]
            offerModel.append({
                oid: o.id,
                name: o.name,
                from: o.from || "",
                fileCount: o.fileCount || (o.files ? o.files.length : 0),
                selected: o.selected || 0,
                size: o.size || 0,
                expanded: i === 0
            })
            const files = o.files || []
            for (let k = 0; k < files.length; k++) {
                fileModel.append({
                    oid: o.id,
                    path: files[k].path,
                    name: files[k].name,
                    size: files[k].size,
                    picked: files[k].on !== false
                })
            }
        }
    }

    function refresh() {
        statusProc.running = false
        statusProc.running = true
    }

    function runCmd(line) {
        cmdProc.command = ["bash", "-lc", "omasyncd " + line]
        cmdProc.running = false
        cmdProc.running = true
    }

    function toggleFile(oid, path) {
        runCmd("toggle " + shellQuote(oid) + " " + shellQuote(path))
    }

    function acceptOffer(oid) {
        runCmd("accept " + shellQuote(oid))
    }

    function dismissOffer(oid) {
        runCmd("dismiss " + shellQuote(oid))
    }

    function selectAll(oid, on) {
        runCmd("select-all " + shellQuote(oid) + " " + (on ? "1" : "0"))
    }

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'"
    }

    function fmtSize(n) {
        n = Number(n) || 0
        if (n < 1000)
            return n + " B"
        if (n < 1000 * 1000)
            return (n / 1000).toFixed(0) + " KB"
        if (n < 1000 * 1000 * 1000)
            return (n / 1000000).toFixed(n >= 10000000 ? 0 : 1) + " MB"
        return (n / 1000000000).toFixed(1) + " GB"
    }

    function openAppWindow() {
        openProc.running = false
        openProc.running = true
    }

    ListModel { id: offerModel }
    ListModel { id: fileModel }

    Process {
        id: statusProc
        command: ["bash", "-lc", "omasyncd status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: panel.applyRaw(this.text)
        }
    }

    Process {
        id: cmdProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: panel.applyRaw(this.text)
        }
    }

    Process {
        id: openProc
        running: false
        command: ["bash", "-lc", "omarchy-launch-webapp '" + panel.appUrl + "' 2>/dev/null || omarchy-launch-browser '" + panel.appUrl + "' 2>/dev/null || xdg-open '" + panel.appUrl + "'"]
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: Style.space ? Style.space(14) : 14
        contentWidth: width
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: flick.width
            spacing: 12

            Item {
                width: parent.width
                height: 28

                Row {
                    spacing: 8
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    OmaSyncIcon {
                        iconSize: 18
                        color: panel.foreground
                        live: true
                        waiting: panel.waiting
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Column {
                        spacing: 1
                        Text {
                            text: "OmaSync"
                            color: panel.foreground
                            font.family: panel.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: panel.daemonRole + " · " + panel.daemonState
                            color: panel.dim
                            font.family: panel.fontFamily
                            font.pixelSize: 10
                        }
                    }
                }
            }

            // Headline
            Column {
                width: parent.width
                spacing: 6
                visible: panel.waiting

                Text {
                    text: "Files waiting"
                    color: panel.green
                    font.family: panel.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: panel.foreground
                    font.family: panel.fontFamily
                    font.pixelSize: 13
                    text: {
                        if (offerModel.count === 1)
                            return "You have a folder called “" + offerModel.get(0).name + "”. Click a file to keep it, then accept."
                        if (offerModel.count > 1) {
                            let names = []
                            for (let i = 0; i < offerModel.count; i++)
                                names.push(offerModel.get(i).name)
                            return "You have folders called " + names.join(" and ") + ". Open one, pick files, then accept."
                        }
                        return ""
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 6
                visible: !panel.waiting

                Text {
                    text: "Nothing waiting"
                    color: panel.foreground
                    font.family: panel.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "When someone nearby shares a folder, this icon breathes green and the names show up here so you can pick which files to keep."
                    color: panel.dim
                    font.family: panel.fontFamily
                    font.pixelSize: 12
                }
            }

            Repeater {
                model: offerModel
                delegate: Column {
                    id: offerBlock
                    width: col.width
                    spacing: 6
                    required property string oid
                    required property string name
                    required property string from
                    required property int fileCount
                    required property int selected
                    required property int size
                    required property bool expanded
                    required property int index

                    Rectangle {
                        width: parent.width
                        height: headCol.implicitHeight + 16
                        radius: 8
                        color: "transparent"
                        border.width: 1
                        border.color: panel.waiting ? panel.green : panel.dim
                        opacity: 0.95

                        Column {
                            id: headCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: 8
                            spacing: 2

                            Text {
                                text: "Folder · " + offerBlock.name
                                color: panel.foreground
                                font.family: panel.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: offerBlock.from + " · " + offerBlock.fileCount + " files · " + panel.fmtSize(offerBlock.size)
                                color: panel.dim
                                font.family: panel.fontFamily
                                font.pixelSize: 11
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: offerModel.setProperty(offerBlock.index, "expanded", !offerBlock.expanded)
                        }
                    }

                    Column {
                        width: parent.width
                        visible: offerBlock.expanded
                        spacing: 2

                        Repeater {
                            model: fileModel
                            delegate: Rectangle {
                                required property string oid
                                required property string path
                                required property string name
                                required property int size
                                required property bool picked
                                width: offerBlock.width
                                height: oid === offerBlock.oid ? 32 : 0
                                visible: oid === offerBlock.oid
                                color: "transparent"

                                Row {
                                    anchors.fill: parent
                                    spacing: 8

                                    Rectangle {
                                        width: 16
                                        height: 16
                                        radius: 3
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: picked ? panel.green : "transparent"
                                        border.width: 1
                                        border.color: picked ? panel.green : panel.dim
                                    }
                                    Text {
                                        text: name
                                        color: panel.foreground
                                        font.family: panel.fontFamily
                                        font.pixelSize: 12
                                        elide: Text.ElideMiddle
                                        width: parent.width - 80
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: panel.fmtSize(size)
                                        color: panel.dim
                                        font.family: panel.fontFamily
                                        font.pixelSize: 11
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: panel.toggleFile(oid, path)
                                }
                            }
                        }

                        Row {
                            spacing: 8
                            height: 30

                            Rectangle {
                                implicitWidth: accLabel.implicitWidth + 16
                                implicitHeight: 26
                                radius: 6
                                color: panel.green

                                Text {
                                    id: accLabel
                                    anchors.centerIn: parent
                                    text: "Accept " + offerBlock.selected + " file" + (offerBlock.selected === 1 ? "" : "s")
                                    color: "#0c0d0b"
                                    font.family: panel.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: panel.acceptOffer(offerBlock.oid)
                                }
                            }

                            Text {
                                text: "Skip folder"
                                color: panel.dim
                                font.family: panel.fontFamily
                                font.pixelSize: 11
                                anchors.verticalCenter: parent.verticalCenter
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: panel.dismissOffer(offerBlock.oid)
                                }
                            }
                        }
                    }
                }
            }

            Text {
                visible: panel.waiting
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Accepted files land in " + panel.destination
                color: panel.dim
                font.family: panel.fontFamily
                font.pixelSize: 11
            }

            Text {
                text: "Open omasync.grok.me"
                color: panel.dim
                font.family: panel.fontFamily
                font.pixelSize: 11
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: panel.openAppWindow()
                }
            }
        }
    }
}
