import QtQuick
import QtQuick.Controls.Basic

// StyledInput v3 — background fill shifts on focus, same as before, plus
// a colored focus ring (Theme.edgeB) so focus is visible at a glance
// instead of only a subtle fill change — doubles as one of the "where's
// this fit" neon touches, since a field you're actively typing into is a
// reasonable place for it.
TextField {
    id: root
    font.family: Theme.fontMono
    font.pixelSize: Math.round(14 * Theme.scale)
    color: Theme.text
    placeholderTextColor: Theme.textFaint
    leftPadding: Theme.sp3
    rightPadding: Theme.sp3
    topPadding: Theme.sp2
    bottomPadding: Theme.sp2
    selectionColor: Theme.accent2

    background: Rectangle {
        radius: Theme.rMd
        color: root.activeFocus ? Theme.surface2 : Theme.surface
        Behavior on color { ColorAnimation { duration: Theme.normal } }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            radius: parent.radius + 1
            color: "transparent"
            border.width: 1.5
            border.color: root.activeFocus ? Theme.edgeB : "transparent"
            Behavior on border.color { ColorAnimation { duration: Theme.normal } }
        }
    }
}
