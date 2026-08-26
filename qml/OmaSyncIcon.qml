import QtQuick

// Two nodes + hub. Box size never changes. Waiting only retints + opacity.
Item {
    id: root
    property real iconSize: 14
    property color color: "#ebe8e0"
    property bool live: true
    property bool waiting: false
    property color waitColor: "#4ade80"

    width: iconSize
    height: iconSize
    implicitWidth: iconSize
    implicitHeight: iconSize
    clip: false

    readonly property real inset: iconSize * 0.14
    readonly property real node: iconSize * 0.22
    readonly property real hub: iconSize * 0.36
    readonly property color restColor: live ? color : Qt.darker(color, 1.45)
    property real glow: 1

    SequentialAnimation on glow {
        running: root.waiting
        loops: Animation.Infinite
        NumberAnimation { from: 0.5; to: 1.0; duration: 2600; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1.0; to: 0.5; duration: 2600; easing.type: Easing.InOutSine }
    }

    Timer {
        interval: 60000
        running: root.waiting
        repeat: true
        onTriggered: flash.restart()
    }

    SequentialAnimation {
        id: flash
        running: false
        loops: 2
        NumberAnimation { target: root; property: "glow"; to: 1.0; duration: 160 }
        NumberAnimation { target: root; property: "glow"; to: 0.45; duration: 160 }
    }

    readonly property color ink: waiting
        ? Qt.rgba(waitColor.r, waitColor.g, waitColor.b, 0.55 + 0.45 * glow)
        : restColor

    Rectangle {
        width: root.node
        height: root.node
        radius: width / 2
        color: root.ink
        anchors.verticalCenter: parent.verticalCenter
        x: root.inset
    }

    Rectangle {
        width: root.node
        height: root.node
        radius: width / 2
        color: root.ink
        anchors.verticalCenter: parent.verticalCenter
        x: root.width - root.inset - width
    }

    Rectangle {
        width: root.hub
        height: root.hub
        radius: width / 2
        color: root.waiting ? root.waitColor : root.ink
        anchors.centerIn: parent
        opacity: root.waiting ? (0.72 + 0.28 * root.glow) : 1
    }

    Rectangle {
        width: Math.max(1.5, root.iconSize * 0.18)
        height: Math.max(1.2, root.iconSize * 0.08)
        color: root.ink
        opacity: 0.9
        anchors.verticalCenter: parent.verticalCenter
        x: root.inset + root.node - 0.4
    }

    Rectangle {
        width: Math.max(1.5, root.iconSize * 0.18)
        height: Math.max(1.2, root.iconSize * 0.08)
        color: root.ink
        opacity: 0.9
        anchors.verticalCenter: parent.verticalCenter
        x: root.width / 2 + root.hub / 2 - 0.4
    }
}
