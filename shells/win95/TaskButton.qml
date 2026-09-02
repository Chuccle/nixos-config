// One window button in the taskbar.
//
// Sunken while its window is focused, raised otherwise — the Win95 way of
// showing which window is active. Icon comes from a heuristic lookup on the
// app id, so windows whose .desktop file cannot be resolved still get a
// button, just without a picture.
import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import "Tokens.js" as Tokens

Bevel {
    id: root

    required property Toplevel window

    readonly property DesktopEntry entry: DesktopEntries.heuristicLookup(root.window.appId)

    raised: !root.window.activated

    Row {
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: Tokens.padding
            rightMargin: Tokens.padding
        }
        spacing: Tokens.padding

        IconImage {
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: Tokens.fontSize
            visible: root.entry !== null
            source: root.entry ? Quickshell.iconPath(root.entry.icon, true) : ""
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - (root.entry ? Tokens.fontSize + Tokens.padding : 0)

            text: root.window.title
            elide: Text.ElideRight
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.fontSize
            font.bold: root.window.activated
            color: Tokens.text
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        // Clicking the focused window's button minimises it, same as the
        // original. Middle click closes, which the original lacked but every
        // taskbar since has had.
        onClicked: event => {
            if (event.button === Qt.MiddleButton) {
                root.window.close();
            } else if (root.window.activated) {
                root.window.minimized = true;
            } else {
                root.window.activate();
            }
        }
    }
}
