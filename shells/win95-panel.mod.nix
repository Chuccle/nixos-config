{
  desktopHomeModules.win95-panel =
    { osConfig, ... }:
    let
      inherit (osConfig) theme;
      inherit (theme) palette;
    in
    {
      # WIN95 TASKBAR
      # Quickshell panel with real two-tone 3D chrome: a `Bevel` component
      # draws light top/left + dark bottom/right edges (raised) or the reverse
      # (sunken), thickness from `theme.borderWidth`. Start button and taskbar
      # face are raised; the divider and clock well are sunken, matching the
      # genuine Win95 taskbar. Colors/metrics come straight from tokens. Loaded
      # via `quickshell -c win95` from the labwc autostart.
      xdg.config.files."quickshell/win95/shell.qml".text = /* qml */ ''
        import QtQuick
        import Quickshell
        import Quickshell.Io
        import Quickshell.Wayland

        ShellRoot {
            // Inline components must be declared inside the document's root
            // object — a QML file has exactly one root, so a top-level
            // `component` before ShellRoot fails to parse.
            component Bevel: Item {
                id: bevel
                property bool raised: true
                property color face: "${palette.surface}"
                property color hi: "${palette.overlay}"
                property color lo: "${palette.muted}"
                property int thickness: ${toString theme.borderWidth}

                Rectangle { anchors.fill: parent; color: bevel.face }

                // top edge
                Rectangle {
                    anchors { top: parent.top; left: parent.left; right: parent.right }
                    height: bevel.thickness
                    color: bevel.raised ? bevel.hi : bevel.lo
                }
                // left edge
                Rectangle {
                    anchors { top: parent.top; left: parent.left; bottom: parent.bottom }
                    width: bevel.thickness
                    color: bevel.raised ? bevel.hi : bevel.lo
                }
                // bottom edge
                Rectangle {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                    height: bevel.thickness
                    color: bevel.raised ? bevel.lo : bevel.hi
                }
                // right edge
                Rectangle {
                    anchors { top: parent.top; right: parent.right; bottom: parent.bottom }
                    width: bevel.thickness
                    color: bevel.raised ? bevel.lo : bevel.hi
                }
            }

            // Menu row, reused by the Start menu popup below.
            component MenuItem: Rectangle {
                id: menuItem
                property string label: ""
                // A real signal, not a `property var` callback: `on<Name>: { ... }`
                // on a plain property is a live binding, evaluated immediately at
                // creation to compute its initial value — not deferred until
                // called. Only an actual `signal` gets deferred `on<Signal>: {}`
                // handler semantics.
                signal activated

                height: ${toString (theme.font.size.normal + theme.padding * 2)}
                color: itemMouse.containsMouse ? "${palette.accent}" : "transparent"

                Text {
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: ${toString theme.padding}
                    }
                    text: menuItem.label
                    font.family: "${theme.font.sans.name}"
                    font.pixelSize: ${toString theme.font.size.normal}
                    color: itemMouse.containsMouse ? "${palette.accentText}" : "${palette.text}"
                }

                MouseArea {
                    id: itemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: menuItem.activated()
                }
            }

            PanelWindow {
                id: bar

                property bool startMenuOpen: false

                anchors {
                    bottom: true
                    left: true
                    right: true
                }
                implicitHeight: ${toString (theme.font.size.big + theme.padding * 4)}
                color: "${palette.surface}"

                // TASKBAR FACE (raised across the whole bar)
                Bevel {
                    anchors.fill: parent
                    raised: true
                }

                // START BUTTON
                Bevel {
                    id: startButton
                    raised: true

                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: ${toString theme.padding}
                    }
                    width: startRow.implicitWidth + ${toString (theme.padding * 3)}
                    height: parent.height - ${toString (theme.padding * 2)}

                    Row {
                        id: startRow
                        anchors.centerIn: parent
                        spacing: ${toString (theme.padding / 2)}

                        Rectangle {
                            width: ${toString theme.font.size.big}
                            height: ${toString theme.font.size.big}
                            anchors.verticalCenter: parent.verticalCenter
                            color: "${palette.accent}"

                            Text {
                                anchors.centerIn: parent
                                text: "⊞"
                                color: "${palette.accentText}"
                                font.bold: true
                                font.pixelSize: ${toString theme.font.size.normal}
                            }
                        }

                        Text {
                            text: "Start"
                            font.bold: true
                            font.family: "${theme.font.sans.name}"
                            font.pixelSize: ${toString theme.font.size.normal}
                            color: "${palette.text}"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: bar.startMenuOpen = !bar.startMenuOpen
                    }
                }

                // DIVIDER (sunken groove after Start, authentic taskbar detail)
                Bevel {
                    id: divider
                    raised: false

                    anchors {
                        left: startButton.right
                        top: parent.top
                        bottom: parent.bottom
                        leftMargin: ${toString theme.padding}
                        topMargin: ${toString theme.padding}
                        bottomMargin: ${toString theme.padding}
                    }
                    width: ${toString theme.borderWidth}
                }

                // WINDOW LIST (open toplevels, via wlr-foreign-toplevel-management)
                ListView {
                    orientation: ListView.Horizontal
                    clip: true
                    spacing: ${toString theme.padding}
                    model: ToplevelManager.toplevels

                    anchors {
                        left: divider.right
                        right: clockWell.left
                        top: parent.top
                        bottom: parent.bottom
                        leftMargin: ${toString theme.padding}
                        rightMargin: ${toString theme.padding}
                        topMargin: ${toString theme.padding}
                        bottomMargin: ${toString theme.padding}
                    }

                    delegate: Bevel {
                        id: taskbarButton
                        required property Toplevel modelData

                        raised: !modelData.activated
                        width: Math.min(200, windowLabel.implicitWidth + ${toString (theme.padding * 3)})
                        height: parent.height

                        Text {
                            id: windowLabel
                            anchors.centerIn: parent
                            text: taskbarButton.modelData.title
                            elide: Text.ElideRight
                            width: taskbarButton.width - ${toString (theme.padding * 2)}
                            font.family: "${theme.font.sans.name}"
                            font.pixelSize: ${toString theme.font.size.normal}
                            color: "${palette.text}"
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: taskbarButton.modelData.activate()
                        }
                    }
                }

                // CLOCK (sunken well, matches the real taskbar clock)
                Bevel {
                    id: clockWell
                    raised: false

                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        rightMargin: ${toString theme.padding}
                    }
                    width: clockText.implicitWidth + ${toString (theme.padding * 2)}
                    height: parent.height - ${toString (theme.padding * 2)}

                    Text {
                        id: clockText
                        anchors.centerIn: parent
                        font.family: "${theme.font.sans.name}"
                        font.pixelSize: ${toString theme.font.size.normal}
                        color: "${palette.text}"

                        Timer {
                            interval: 1000
                            running: true
                            repeat: true
                            triggeredOnStart: true
                            onTriggered: clockText.text = Qt.formatDateTime(new Date(), "hh:mm AP")
                        }
                    }
                }
            }

            // START MENU
            // Floats above the taskbar, anchored to the Start button. Only
            // two real actions for now (power state); a program list would
            // need an actual launcher/app index, out of scope here.
            PopupWindow {
                id: startMenu
                anchor.window: bar
                anchor.rect.x: ${toString theme.padding}
                anchor.rect.y: -height
                implicitWidth: 180
                implicitHeight: menuColumn.implicitHeight + ${toString (theme.padding * 2)}
                visible: bar.startMenuOpen
                color: "transparent"

                Bevel {
                    anchors.fill: parent
                    raised: true
                }

                Column {
                    id: menuColumn
                    anchors.fill: parent
                    anchors.margins: ${toString theme.padding}

                    MenuItem {
                        width: parent.width
                        label: "Shut Down..."
                        onActivated: {
                            bar.startMenuOpen = false;
                            shutdownProc.running = true;
                        }
                    }

                    MenuItem {
                        width: parent.width
                        label: "Restart"
                        onActivated: {
                            bar.startMenuOpen = false;
                            restartProc.running = true;
                        }
                    }
                }

                Process {
                    id: shutdownProc
                    command: [ "systemctl", "poweroff" ]
                }

                Process {
                    id: restartProc
                    command: [ "systemctl", "reboot" ]
                }
            }
        }
      '';
    };
}
