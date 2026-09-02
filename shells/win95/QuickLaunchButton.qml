// One Quick Launch slot: icon only, raised until pressed.
import QtQuick
import Quickshell
import Quickshell.Widgets
import "Tokens.js" as Tokens

Bevel {
    id: root

    required property DesktopEntry entry

    raised: !mouse.pressed
    width: height

    IconImage {
        anchors.centerIn: parent
        implicitSize: Tokens.iconSize
        source: Quickshell.iconPath(root.entry.icon, true)
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true


        onClicked: root.entry.execute()
    }
}
