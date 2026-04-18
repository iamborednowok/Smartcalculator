import QtQuick
import QtQuick.Controls.Basic

TextField {
    id: root
    font.family: Theme.fontMono
    font.pixelSize: 14
    color: Theme.inputText
    placeholderTextColor: Theme.inputPlaceholder
    leftPadding: 14; rightPadding: 14
    topPadding: 11; bottomPadding: 11

    Behavior on color { ColorAnimation { duration: Theme.normal } }

    background: Rectangle {
        radius: 14
        color: Theme.inputBg
        border.color: root.activeFocus ? Theme.inputFocusBdr : Theme.inputBdr
        border.width: 1
        Behavior on color       { ColorAnimation { duration: Theme.normal } }
        Behavior on border.color{ ColorAnimation { duration: 150 } }

        // Top sheen
        Rectangle {
            anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.45; height: 1; y: 1; radius: 1
            color: Qt.rgba(1, 1, 1, root.activeFocus ? (Theme.dark ? 0.18 : 0.90) : (Theme.dark ? 0.08 : 0.60))
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        // Focus glow
        Rectangle {
            visible: root.activeFocus
            anchors.fill: parent; anchors.margins: -5
            radius: parent.radius + 5; color: "transparent"
            border.color: Theme.accentDim; border.width: 1; z: -1
        }
    }
}
