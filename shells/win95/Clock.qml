// The taskbar clock, in its sunken well.
//
// SystemClock at minute precision rather than a 1s Timer: the shell wakes
// once a minute instead of sixty times, and the text only re-renders when the
// displayed value actually changes.
import QtQuick
import Quickshell
import "Tokens.js" as Tokens

Bevel {
    id: root

    raised: false

    implicitWidth: label.implicitWidth + Tokens.padding * 3
    implicitHeight: label.implicitHeight + Tokens.padding

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: Qt.formatDateTime(clock.date, Tokens.clockFormat)
        font.family: Tokens.fontFamily
        font.pixelSize: Tokens.fontSize
        color: Tokens.text
    }

}
