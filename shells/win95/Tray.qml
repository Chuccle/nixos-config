// The notification area — the half of a Win95 taskbar that was missing
// entirely. Sunken well, one icon per StatusNotifierItem, left click
// activates and right click opens the item's own DBus menu.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import "Tokens.js" as Tokens

Bevel {
    id: root

    raised: false
    visible: items.count > 0

    implicitWidth: row.implicitWidth + Tokens.padding * 2
    implicitHeight: Tokens.iconSize + Tokens.padding

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.padding

        Repeater {
            id: items
            model: SystemTray.items

            delegate: MouseArea {
                id: entry
                required property SystemTrayItem modelData

                implicitWidth: Tokens.iconSize
                implicitHeight: Tokens.iconSize

                acceptedButtons: Qt.LeftButton | Qt.RightButton
                hoverEnabled: true


                onClicked: event => {
                    if (event.button === Qt.RightButton && entry.modelData.hasMenu) {
                        menu.open();
                    } else {
                        entry.modelData.activate();
                    }
                }

                IconImage {
                    anchors.fill: parent
                    source: entry.modelData.icon
                }

                QsMenuAnchor {
                    id: menu
                    // Quickshell does not export DBusMenuHandle in its qmltypes, so
                    // the linter cannot resolve a type that is fine at runtime.
                    menu: entry.modelData.menu // qmllint disable unresolved-type
                    anchor.item: entry
                    anchor.edges: Edges.Top // qmllint disable missing-type
                }
            }
        }
    }
}
