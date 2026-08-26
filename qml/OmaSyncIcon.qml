import QtQuick
import qs.Commons

// Two nodes + hub. Reads at bar size.
Item {
    id: root
    property real iconSize: 12
    property color color: Color.foreground
    property bool live: true

    width: iconSize
    height: iconSize
    implicitWidth: iconSize
    implicitHeight: iconSize

    readonly property color hubColor: live ? color : Qt.darker(color, 1.45)

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
        color: root.hubColor
        anchors.centerIn: parent
        opacity: root.live ? 1 : 0.7
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
