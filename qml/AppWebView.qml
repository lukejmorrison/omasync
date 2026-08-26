import QtQuick
import QtWebEngine

// Isolated so a missing QtWebEngine does not take down the bar widget.
WebEngineView {
    id: web
    url: "https://omasync.grok.me/"
    backgroundColor: "#0c0d0b"
    settings.javascriptEnabled: true
    settings.localContentCanAccessRemoteUrls: true
    settings.pluginsEnabled: false
    settings.focusOnNavigationEnabled: true
    settings.errorPageEnabled: true
}
