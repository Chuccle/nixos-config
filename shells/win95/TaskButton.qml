import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import "Tokens.js" as Tokens

Bevel {
    id: root

    required property var window
    required property WindowBackend backend

    readonly property DesktopEntry entry: DesktopEntries.heuristicLookup(root.window.app_id || "")

    raised: !root.window.is_focused

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

            text: root.window.title || root.window.app_id || "Application"
            elide: Text.ElideRight
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.fontSize
            font.bold: root.window.is_focused
            color: Tokens.text
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        onClicked: event => {
            if (event.button === Qt.MiddleButton) {
                root.backend.send("close", root.window.id);
            } else if (event.button === Qt.RightButton) {
                actions.popup();
            } else {
                root.backend.send("toggle", root.window.id);
            }
        }
    }
    Controls.Menu {
        id: actions
        font.family: Tokens.fontFamily
        palette.window: Tokens.surface
        palette.text: Tokens.text
        palette.highlight: Tokens.accent
        palette.highlightedText: Tokens.accentText
        Controls.MenuItem { text: "Restore"; onTriggered: root.backend.send("restore", root.window.id) }
        Controls.MenuItem { text: "Minimize"; onTriggered: root.backend.send("hide", root.window.id) }
        Controls.MenuItem { text: "Maximize"; onTriggered: root.backend.send("maximize", root.window.id) }
        Controls.MenuItem { text: "Close"; onTriggered: root.backend.send("close", root.window.id) }
    }
}
