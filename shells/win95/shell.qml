pragma ComponentBehavior: Bound
import Quickshell

ShellRoot {
    WindowBackend { id: windowBackend }

    Variants {
        model: Quickshell.screens

        delegate: Taskbar {
            required property ShellScreen modelData
            screen: modelData
            backend: windowBackend
        }
    }
}
