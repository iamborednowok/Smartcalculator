import QtQuick

Rectangle {
    id: root
    property string label: ""
    property bool   active: false
    signal clicked()

    height: 30
    width:  lbl.implicitWidth + 22
    radius: 15

    color: active ? Qt.rgba(0.49, 0.23, 0.93, 0.20) : Qt.rgba(1, 1, 1, 0.045)
    border.color: active ? Qt.rgba(0.67, 0.55, 1.0, 0.44) : Qt.rgba(1, 1, 1, 0.09)
    border.width: 1
    Behavior on color { ColorAnimation { duration: 130 } }
    Behavior on border.color { ColorAnimation { duration: 130 } }

    // Active: top sheen
    Rectangle {
        anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width * 0.55; height: 1; y: 1; radius: 1
        color: Qt.rgba(1, 1, 1, active ? 0.24 : 0.08)
        Behavior on color { ColorAnimation { duration: 130 } }
    }

    // Active: outer glow
    Rectangle {
        visible: active
        anchors.fill: parent; anchors.margins: -4
        radius: parent.radius + 4
        color: "transparent"
        border.color: Qt.rgba(0.49, 0.23, 0.93, 0.18); border.width: 1; z: -1
    }

    Text {
        id: lbl
        anchors.centerIn: parent
        text: root.label
        font.pixelSize: 10; font.family: "DM Sans"; font.weight: Font.Medium
        color: active ? "#C4B5FD" : "#44446a"
        Behavior on color { ColorAnimation { duration: 130 } }
    }

    scale: ma.pressed ? 0.88 : 1.0
    Behavior on scale { NumberAnimation { duration: 70; easing.type: Easing.OutBack } }

    MouseArea { id: ma; anchors.fill: parent; onClicked: root.clicked() }
}
