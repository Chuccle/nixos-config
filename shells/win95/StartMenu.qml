// The Start menu.
//
// The vertical banner down the left edge is the detail that makes this read
// as Win95 rather than "a list in a grey box", so it is drawn rather than
// skipped. The programs list is real: DesktopEntries is Quickshell's index of
// installed .desktop files, so it reflects whatever the system actually has.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "Tokens.js" as Tokens

PopupWindow {
    id: root

    property string bannerText: "Windows 95"

    signal dismissed

    implicitWidth: 260
    implicitHeight: Math.min(480, layout.implicitHeight + Tokens.borderWidth * 2)
    color: "transparent"

    Bevel {
        anchors.fill: parent
        raised: true
    }

    Row {
        id: layout
        anchors.fill: parent
        anchors.margins: Tokens.borderWidth

        // BANNER
        // Bottom-up sideways text on a navy gradient, exactly as the original.
        Rectangle {
            width: Tokens.fontSize + Tokens.padding * 2
            height: parent.height

            gradient: Gradient {
                GradientStop { position: 0.0; color: Tokens.accent }
                GradientStop { position: 1.0; color: Tokens.base }
            }

            Text {
                anchors.centerIn: parent
                rotation: -90
                width: parent.height

                text: root.bannerText
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.fontSize
                font.bold: true
                color: Tokens.accentText
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
            }
        }

        Column {
            width: parent.width - Tokens.fontSize - Tokens.padding * 2

            // PROGRAMS
            // Alphabetical, and anything marked NoDisplay is filtered out so
            // the menu shows launchable applications rather than every
            // registered MIME handler.
            ListView {
                width: parent.width
                height: Math.min(360, contentHeight)
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                model: ScriptModel {
                    values: [...DesktopEntries.applications.values]
                        .filter(entry => !entry.noDisplay)
                        .sort((a, b) => a.name.localeCompare(b.name))
                }

                delegate: MenuItem {
                    required property DesktopEntry modelData

                    width: ListView.view.width
                    label: modelData.name
                    icon: modelData.icon

                    onActivated: {
                        modelData.execute();
                        root.dismissed();
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: Tokens.borderWidth
                color: Tokens.muted
            }

            MenuItem {
                width: parent.width
                label: "Shut Down..."
                onActivated: {
                    root.dismissed();
                    shutdown.running = true;
                }
            }

            MenuItem {
                width: parent.width
                label: "Restart"
                onActivated: {
                    root.dismissed();
                    restart.running = true;
                }
            }
        }
    }

    Process {
        id: shutdown
        command: ["systemctl", "poweroff"]
    }

    Process {
        id: restart
        command: ["systemctl", "reboot"]
    }
}
