import QtQuick
import qs.Ui

// Super-key / omarchy-shell shell toggle wizwam.omasync '{}'
Panel {
    id: root
    moduleName: "wizwam.omasync"
    ipcTarget: "wizwam.omasync-menu"

    implicitWidth: 720
    implicitHeight: 560

    Loader {
        anchors.fill: parent
        source: "Panel.qml"
        onLoaded: {
            if (item)
                item.bar = root.bar
        }
    }
}
