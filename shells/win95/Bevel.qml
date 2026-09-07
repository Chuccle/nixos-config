// The one visual primitive the whole shell is built from.
//
// Win95 chrome is a *double* 3D edge, not a single one: an outer ring in the
// extreme tones (white and black) and an inner ring in the mid tones (light
// grey and dark grey), with both pairs swapped when the surface is sunken.
// Drawing only the inner pair is what makes most recreations read as "a grey
// box with a border" — it is the outer white/black ring that makes a button
// look pressable. Every button, well and panel below is a Bevel with `raised`
// set accordingly, so the look stays consistent and the depth tracks one
// token.
import QtQuick
import "Tokens.js" as Tokens

Item {
    id: root

    property bool raised: true
    property color face: Tokens.surface
    property int thickness: Tokens.borderWidth

    // The outer ring takes half the thickness (at least one pixel) and the
    // inner ring what is left, so `theme.borderWidth` still decides the total
    // depth. At a thickness of 1 the inner ring is zero-height and simply
    // does not draw.
    readonly property int outerThickness: Math.max(1, Math.floor(root.thickness / 2))
    readonly property int innerThickness: root.thickness - root.outerThickness

    // Highlight and shadow swap when the surface is sunken, which is the
    // whole trick — the same rectangles read as pressed or raised depending
    // only on which side gets the light.
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
