import QtQuick
import QtQuick.Controls.Basic

TextField {
    id: root
    font.family: "DM Mono"
    font.pixelSize: 14
    color: "#f0f0ff"
    placeholderTextColor: "#44446a"
    leftPadding: 14; rightPadding: 14
    topPadding: 11; bottomPadding: 11

    background: Rectangle {
        radius: 14
        color: Qt.rgba(1, 1, 1, 0.055)
        border.color: root.activeFocus
            ? Qt.rgba(0.49, 0.23, 0.93, 0.65)
            : Qt.rgba(1, 1, 1, 0.10)
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: 150 } }

        // Top sheen
        Rectangle {
            anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.45; height: 1; y: 1; radius: 1
            color: Qt.rgba(1, 1, 1, root.activeFocus ? 0.18 : 0.08)
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        // Focus glow
        Rectangle {
            visible: root.activeFocus
            anchors.fill: parent; anchors.margins: -5
            radius: parent.radius + 5
            color: "transparent"
            border.color: Qt.rgba(0.49, 0.23, 0.93, 0.20); border.width: 1; z: -1
        }
    }
}
