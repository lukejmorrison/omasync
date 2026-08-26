import QtQuick
import qs.Ui

// Summoned from the Omarchy menu / application launcher:
//   omarchy-shell shell toggle wizwam.omasync '{}'
Panel {
    id: root
    moduleName: "wizwam.omasync"
    ipcTarget: "wizwam.omasync-menu"

    Loader {
        anchors.fill: parent
        source: "Panel.qml"
    }
}
