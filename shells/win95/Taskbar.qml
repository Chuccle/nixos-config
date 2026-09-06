// The taskbar itself.
//
// Left to right: Start, a sunken divider, Quick Launch, the window list,
// then the notification area and clock pinned right — the genuine Win95
// layout rather than a modern bar wearing grey.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "Tokens.js" as Tokens

PanelWindow {
    id: root

    property bool menuOpen: false

    anchors {
        bottom: true
        left: true
        right: true
    }

    implicitHeight: Tokens.iconSize + Tokens.padding * 3
    color: Tokens.surface

    Bevel {
        anchors.fill: parent
        raised: true
    }

    // START
    // Sunken while the menu is open, which is how the original showed the
    // button as held down.
    Bevel {
        id: startButton

        raised: !root.menuOpen

        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
            leftMargin: Tokens.padding
        }
        width: startRow.implicitWidth + Tokens.padding * 3
        height: parent.height - Tokens.padding * 2

        Row {
            id: startRow
            anchors.centerIn: parent
            spacing: Tokens.padding

            // The four-pane flag, drawn rather than shipped as an asset.
            Grid {
                anchors.verticalCenter: parent.verticalCenter
                columns: 2
                spacing: 1

                Repeater {
                    model: [Tokens.red, Tokens.green, Tokens.blue, Tokens.yellow]

                    delegate: Rectangle {
                        required property color modelData
                        width: Math.floor(Tokens.fontSize / 2)
                        height: Math.floor(Tokens.fontSize / 2)
                        color: modelData
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Tokens.startLabel
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.fontSize
                font.bold: true
                color: Tokens.text
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.menuOpen = !root.menuOpen
        }
    }

    Bevel {
        id: startDivider
        raised: false

        anchors {
            left: startButton.right
            top: parent.top
            bottom: parent.bottom
            leftMargin: Tokens.padding
            topMargin: Tokens.padding
            bottomMargin: Tokens.padding
        }
        width: Tokens.borderWidth
    }

    // QUICK LAUNCH
    // Icon-only launchers for the handful of things worth one click. Entries
    // that are not installed resolve to null and are skipped, so the row
    // never shows a broken button.
    Row {
        id: quickLaunch

        anchors {
            left: startDivider.right
            verticalCenter: parent.verticalCenter
            leftMargin: Tokens.padding
        }
        spacing: Tokens.padding

        Repeater {
            model: ScriptModel {
                values: Tokens.quickLaunch
                    .map(id => DesktopEntries.byId(id))
                    .filter(entry => entry !== null)
            }

            delegate: QuickLaunchButton {
                required property DesktopEntry modelData
                entry: modelData
                height: Tokens.iconSize + Tokens.padding
            }
        }
    }

    Bevel {
        id: launchDivider
        raised: false
        visible: quickLaunch.children.length > 0

        anchors {
            left: quickLaunch.right
            top: parent.top
            bottom: parent.bottom
            leftMargin: Tokens.padding
            topMargin: Tokens.padding
            bottomMargin: Tokens.padding
        }
        width: Tokens.borderWidth
    }

    // WINDOW LIST
    // The open toplevels, via wlr-foreign-toplevel-management. This is the
    // taskbar's actual job, so it takes all the space Start and the tray
    // leave behind.
    ListView {
        orientation: ListView.Horizontal
        clip: true
        spacing: Tokens.padding

        anchors {
            left: launchDivider.right
            right: tray.left
            top: parent.top
            bottom: parent.bottom
            leftMargin: Tokens.padding
            rightMargin: Tokens.padding
            topMargin: Tokens.padding
            bottomMargin: Tokens.padding
        }

        model: ToplevelManager.toplevels

        delegate: TaskButton {
            required property Toplevel modelData

            window: modelData
            width: Math.min(Tokens.taskButtonWidth, ListView.view.width / Math.max(1, ListView.view.count))
            height: ListView.view.height
        }
    }

    Tray {
        id: tray

        anchors {
            right: clock.left
            verticalCenter: parent.verticalCenter
            rightMargin: Tokens.padding
        }
    }

    Clock {
        id: clock

        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
            rightMargin: Tokens.padding
        }
    }

    StartMenu {
        anchor.window: root
        anchor.rect.x: Tokens.padding
        anchor.rect.y: -height
        visible: root.menuOpen
        onDismissed: root.menuOpen = false
    }
}
