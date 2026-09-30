import QtQuick
import "Tokens.js" as Tokens

Item {
    id: root

    property bool raised: true
    property color face: Tokens.surface
    property int thickness: Tokens.borderWidth

    readonly property int outerThickness: Math.max(1, Math.floor(root.thickness / 2))
    readonly property int innerThickness: root.thickness - root.outerThickness

    readonly property color outerLight: root.raised ? Tokens.edgeLight : Tokens.edgeShade
    readonly property color outerShade: root.raised ? Tokens.edgeShade : Tokens.edgeLight
    readonly property color innerLight: root.raised ? Tokens.overlay : Tokens.muted
    readonly property color innerShade: root.raised ? Tokens.muted : Tokens.overlay

    Rectangle {
        anchors.fill: parent
        color: root.face
    }

    // OUTER RING
    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: root.outerThickness
        color: root.outerLight
    }

    Rectangle {
        anchors { top: parent.top; left: parent.left; bottom: parent.bottom }
        width: root.outerThickness
        color: root.outerLight
    }

    Rectangle {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: root.outerThickness
        color: root.outerShade
    }

    Rectangle {
        anchors { top: parent.top; right: parent.right; bottom: parent.bottom }
        width: root.outerThickness
        color: root.outerShade
    }

    // INNER RING
    Rectangle {
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: root.outerThickness
            leftMargin: root.outerThickness
            rightMargin: root.outerThickness
        }
        height: root.innerThickness
        color: root.innerLight
    }

    Rectangle {
        anchors {
            top: parent.top
            left: parent.left
            bottom: parent.bottom
            topMargin: root.outerThickness
            leftMargin: root.outerThickness
            bottomMargin: root.outerThickness
        }
        width: root.innerThickness
        color: root.innerLight
    }

    Rectangle {
        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            bottomMargin: root.outerThickness
            leftMargin: root.outerThickness
            rightMargin: root.outerThickness
        }
        height: root.innerThickness
        color: root.innerShade
    }

    Rectangle {
        anchors {
            top: parent.top
            right: parent.right
            bottom: parent.bottom
            topMargin: root.outerThickness
            rightMargin: root.outerThickness
            bottomMargin: root.outerThickness
        }
        width: root.innerThickness
        color: root.innerShade
    }
}
