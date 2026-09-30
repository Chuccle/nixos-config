pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import "Tokens.js" as Tokens

Item {
    id: root
    property var windows: []
    property var parked: []
    property var pending: []
    property string error: ""

    function send(action, id) {
        const command = [Tokens.windowCommand, action];
        if (id !== undefined) command.push(String(id));
        root.pending = [...root.pending, command];
        root.startNext();
    }
    function startNext() {
        if (control.running || root.pending.length === 0) return;
        control.command = root.pending[0];
        root.pending = root.pending.slice(1);
        control.running = true;
    }
    Component.onCompleted: root.send("state")

    Process {
        id: events
        running: true
        command: [Tokens.niriCommand, "msg", "--json", "event-stream"]
        onRunningChanged: if (!events.running) restartEvents.start()
        stdout: SplitParser {
            onRead: line => {
                try {
                    const event = JSON.parse(line);
                    if (event.WindowsChanged) root.windows = event.WindowsChanged.windows;
                    else if (event.WindowOpenedOrChanged) {
                        const window = event.WindowOpenedOrChanged.window;
                        const remaining = root.windows.filter(w => w.id !== window.id).map(w => {
                            if (window.is_focused) w.is_focused = false;
                            return w;
                        });
                        root.windows = remaining.concat([window]).sort((a, b) => a.id - b.id);
                    } else if (event.WindowClosed) {
                        root.windows = root.windows.filter(w => w.id !== event.WindowClosed.id);
                        root.parked = root.parked.filter(id => id !== event.WindowClosed.id);
                    } else if (event.WindowFocusChanged) root.windows = root.windows.map(w => {
                        w.is_focused = w.id === event.WindowFocusChanged.id;
                        return w;
                    });
                } catch (e) { root.error = String(e); }
            }
        }
    }
    Timer {
        id: restartEvents
        interval: 1000
        onTriggered: events.running = true
    }
    Process {
        id: control
        stdout: SplitParser {
            onRead: line => {
                try {
                    const state = JSON.parse(line);
                    if (state.parked) root.parked = state.parked;
                } catch (e) { /* upstream command diagnostics are not state */ }
            }
        }
        stderr: SplitParser { onRead: line => root.error = line }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) root.error = "";
            Qt.callLater(root.startNext);
        }
    }
}
