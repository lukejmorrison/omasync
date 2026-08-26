import Quickshell
import Quickshell.Io

// Headless singleton. Keeps omasyncd alive for the session.
QtObject {
    id: daemon

    Process {
        id: proc
        command: ["bash", "-lc", "omasyncd status >/dev/null 2>&1 || omasyncd"]
        running: true
    }
}
