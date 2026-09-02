// Win95 shell root.
//
// One taskbar per screen. Everything else hangs off it — the components live
// in sibling files rather than one inline document, so each is a real QML
// file that qmllint checks at build time.
import Quickshell

ShellRoot {
    Variants {
        model: Quickshell.screens

        delegate: Taskbar {
            required property ShellScreen modelData
            screen: modelData
        }
    }
}
