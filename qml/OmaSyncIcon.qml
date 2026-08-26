import QtQuick

// Two nodes + hub. When `waiting` is set the hub breathes green;
// once a minute it does a stronger 3-beat flash.
Item {
    id: root
    property real iconSize: 12
    property color color: "#ebe8e0"
    property bool live: true
    property bool waiting: false
    property color waitColor: "#4ade80"

    width: iconSize
    height: iconSize
    implicitWidth: iconSize
    implicitHeight: iconSize

    readonly property color restColor: live ? color : Qt.darker(color, 1.45)
    property real pulse: waiting ? 0.45 : 1
    property bool minuteFlash: false

    readonly property color hubColor: waiting
        ? Qt.rgba(waitColor.r, waitColor.g, waitColor.b, 0.55 + 0.45 * pulse)
        : restColor

    SequentialAnimation on pulse {
        running: root.waiting && !root.minuteFlash
        loops: Animation.Infinite
        NumberAnimation { from: 0.35; to: 1.0; duration: 2200; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1.0; to: 0.35; duration: 2200; easing.type: Easing.InOutSine }
    }

    SequentialAnimation {
        id: minutePulse
        running: false
        loops: 3
        NumberAnimation { target: root; property: "pulse"; from: 0.2; to: 1.0; duration: 280; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "pulse"; from: 1.0; to: 0.2; duration: 280; easing.type: Easing.InQuad }
        onStopped: root.minuteFlash = false
    }

    Timer {
        interval: 60000
        running: root.waiting
        repeat: true
        onTriggered: {
            root.minuteFlash = true
            minutePulse.restart()
        }
    }

    // Soft green halo so the chip reads as "alert" even at 12px.
    Rectangle {
        visible: root.waiting
        anchors.centerIn: parent
        width: root.iconSize * (1.15 + 0.25 * root.pulse)
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 1.2
        border.color: root.waitColor
        opacity: 0.25 + 0.55 * root.pulse
    }

    Rectangle {
        width: root.iconSize * 0.22
        height: root.iconSize * 0.22
        radius: width / 2
        color: root.hubColor
        anchors.verticalCenter: parent.verticalCenter
        x: 0
    }

    Rectangle {
        width: root.iconSize * 0.22
        height: root.iconSize * 0.22
        radius: width / 2
        color: root.hubColor
        anchors.verticalCenter: parent.verticalCenter
        x: root.iconSize - width
    }

    Rectangle {
        width: root.iconSize * 0.42
        height: root.iconSize * 0.42
        radius: width / 2
        color: root.waiting ? root.waitColor : root.hubColor
        anchors.centerIn: parent
        opacity: root.waiting ? (0.65 + 0.35 * root.pulse) : (root.live ? 1 : 0.7)
    }

    Rectangle {
        width: root.iconSize * 0.18
        height: Math.max(1.5, root.iconSize * 0.08)
        color: root.hubColor
        opacity: 0.85
        anchors.verticalCenter: parent.verticalCenter
        x: root.iconSize * 0.18
    }

    Rectangle {
        width: root.iconSize * 0.18
        height: Math.max(1.5, root.iconSize * 0.08)
        color: root.hubColor
        opacity: 0.85
        anchors.verticalCenter: parent.verticalCenter
        x: root.iconSize * 0.64
    }
}
