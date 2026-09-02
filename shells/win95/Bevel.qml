// The one visual primitive the whole shell is built from.
//
// Win95 chrome is entirely two-tone 3D edges: a light top/left and a dark
// bottom/right for a raised surface, the reverse for a sunken one. Every
// button, well and panel below is a Bevel with `raised` set accordingly, so
// the look stays consistent and the thickness tracks one token.
import QtQuick
import "Tokens.js" as Tokens

Item {
    id: root

    property bool raised: true
    property color face: Tokens.surface
    property int thickness: Tokens.borderWidth

    // Highlight and shadow swap when the surface is sunken, which is the
    // whole trick — the same four rectangles read as pressed or raised
    // depending only on which pair gets the light.
    readonly property color light: root.raised ? Tokens.overlay : Tokens.muted
    readonly property color shade: root.raised ? Tokens.muted : Tokens.overlay

    Rectangle {
        anchors.fill: parent
        color: root.face
    }

    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: root.thickness
        color: root.light
    }

    Rectangle {
        anchors { top: parent.top; left: parent.left; bottom: parent.bottom }
        width: root.thickness
        color: root.light
    }

    Rectangle {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: root.thickness
        color: root.shade
    }

    Rectangle {
        anchors { top: parent.top; right: parent.right; bottom: parent.bottom }
        width: root.thickness
        color: root.shade
    }
}
