pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "Tokens.js" as Tokens

PopupWindow {
    id: root

    property string bannerText: Tokens.bannerText
    readonly property bool confirmationVisible: confirmation.visible
    readonly property var entries: [...DesktopEntries.applications.values]
        .filter(entry => !entry.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))

    signal dismissed
    signal showDesktopRequested

    implicitWidth: Tokens.menuWidth
    implicitHeight: Math.min(Tokens.menuHeight, layout.implicitHeight + Tokens.borderWidth * 2)
    color: "transparent"
    grabFocus: true
    onVisibleChanged: {
        if (visible) {
            keyboardScope.selection = 0;
            Qt.callLater(() => keyboardScope.forceActiveFocus());
        }
        else root.dismissed();
    }

    Bevel {
        anchors.fill: parent
        raised: true
    }

    FocusScope {
        id: keyboardScope
        anchors.fill: parent
        focus: true
        property int selection: 0
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.dismissed();
                event.accepted = true;
            } else if (event.key === Qt.Key_Down) {
                keyboardScope.selection = Math.min(programs.count + 2, keyboardScope.selection + 1);
                if (keyboardScope.selection < programs.count) programs.positionViewAtIndex(keyboardScope.selection, ListView.Contain);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up) {
                keyboardScope.selection = Math.max(0, keyboardScope.selection - 1);
                if (keyboardScope.selection < programs.count) programs.positionViewAtIndex(keyboardScope.selection, ListView.Contain);
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (keyboardScope.selection < programs.count) {
                    root.entries[keyboardScope.selection].execute();
                    root.dismissed();
                } else if (keyboardScope.selection === programs.count) {
                    root.showDesktopRequested();
                    root.dismissed();
                } else {
                    confirmation.action = keyboardScope.selection === programs.count + 1 ? "poweroff" : "reboot";
                    confirmation.visible = true;
                }
                event.accepted = true;
            }
        }

    Row {
        id: layout
        anchors.fill: parent
        anchors.margins: Tokens.borderWidth

        // BANNER
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
            ListView {
                id: programs
                width: parent.width
                height: Math.min(contentHeight, Tokens.menuHeight - powerOptions.height)
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                model: ScriptModel {
                    values: root.entries
                }

                delegate: MenuItem {
                    required property int index
                    required property DesktopEntry modelData

                    width: ListView.view.width
                    label: modelData.name
                    icon: modelData.icon
                    selected: keyboardScope.selection === index

                    onActivated: {
                        modelData.execute();
                        root.dismissed();
                    }
                }
            }

            // POWER
            Column {
                id: powerOptions

                width: parent.width

                Rectangle {
                    width: parent.width
                    height: Tokens.borderWidth
                    color: Tokens.muted
                }

                MenuItem {
                    width: parent.width
                    label: "Show Desktop"
                    selected: keyboardScope.selection === programs.count
                    onActivated: {
                        root.showDesktopRequested();
                        root.dismissed();
                    }
                }

                MenuItem {
                    width: parent.width
                    label: "Shut Down..."
                    selected: keyboardScope.selection === programs.count + 1
                    onActivated: {
                        confirmation.action = "poweroff";
                        confirmation.visible = true;
                    }
                }

                MenuItem {
                    width: parent.width
                    label: "Restart"
                    selected: keyboardScope.selection === programs.count + 2
                    onActivated: {
                        confirmation.action = "reboot";
                        confirmation.visible = true;
                    }
                }
            }
        }
    }
    }

    PopupWindow {
        id: confirmation
        property string action: "poweroff"
        anchor.window: root
        implicitWidth: Tokens.menuWidth
        implicitHeight: 110
        color: Tokens.surface
        grabFocus: true
        onVisibleChanged: if (visible) Qt.callLater(() => confirmationScope.forceActiveFocus());

        FocusScope {
            id: confirmationScope
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    confirmation.visible = false;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    power.command = confirmation.action === "poweroff" ? Tokens.powerShutdown : Tokens.powerRestart;
                    power.running = true;
                    event.accepted = true;
                }
            }

            Column {
                anchors.fill: parent
                anchors.margins: Tokens.padding
                Text {
                    text: confirmation.action === "poweroff" ? "Shut down this computer?" : "Restart this computer?"
                    color: Tokens.text
                    font.family: Tokens.fontFamily
                }
                MenuItem {
                    width: parent.width
                    label: "Yes"
                    onActivated: {
                        power.command = confirmation.action === "poweroff" ? Tokens.powerShutdown : Tokens.powerRestart;
                        power.running = true;
                    }
                }
                MenuItem {
                    width: parent.width
                    label: "Cancel"
                    onActivated: confirmation.visible = false
                }
            }
        }
    }

    Process { id: power }
}
