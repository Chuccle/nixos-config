// One row of the Start menu: an optional icon, a label, and the navy
// hover bar that is the single most recognisable Win95 interaction.
import QtQuick
import Quickshell
import Quickshell.Widgets
import "Tokens.js" as Tokens

Rectangle {
    id: root

    property string label: ""
    property string icon: ""
    property bool submenu: false

    // A real signal, not a `property var` callback. `on<Name>:` on a plain
    // property is a live binding evaluated immediately at creation to compute
    // its initial value — only an actual signal gets deferred handler
    // semantics.
    signal activated

    implicitHeight: Math.max(Tokens.fontSize + Tokens.padding * 2, Tokens.iconSize + Tokens.padding)
    color: mouse.containsMouse ? Tokens.accent : "transparent"

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
            implicitSize: Tokens.iconSize
            source: root.icon ? Quickshell.iconPath(root.icon, true) : ""
            visible: root.icon !== ""
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            elide: Text.ElideRight
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.fontSize
            color: mouse.containsMouse ? Tokens.accentText : Tokens.text
        }
    }

    Text {
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
            rightMargin: Tokens.padding
        }
        visible: root.submenu
        text: "▶"
        font.pixelSize: Tokens.fontSize - 2
        color: mouse.containsMouse ? Tokens.accentText : Tokens.text
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.activated()
    }
}
