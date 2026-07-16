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

            PanelWindow {
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
                }

                // DIVIDER (sunken groove after Start, authentic taskbar detail)
                Bevel {
                    raised: false
                    thickness: 1

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

                // CLOCK (sunken well, matches the real taskbar clock)
                Bevel {
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
        }
      '';
    };
}
