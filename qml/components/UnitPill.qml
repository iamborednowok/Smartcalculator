import QtQuick

Rectangle {
    id: root
    property string label: ""
    property bool   active: false
    signal clicked()

    height: 28
    width:  lbl.implicitWidth + 22
    radius: 14

    color: active ? Theme.pillActiveBg : Theme.pillInactiveBg
    border.color: active ? Theme.pillActiveBdr : Theme.pillInactiveBdr
    border.width: 1
    Behavior on color       { ColorAnimation { duration: 130 } }
    Behavior on border.color{ ColorAnimation { duration: 130 } }

    // Top sheen
    Rectangle {
        anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width * 0.55; height: 1; y: 1; radius: 1
        color: Qt.rgba(1, 1, 1, active ? (Theme.dark ? 0.24 : 0.90) : (Theme.dark ? 0.08 : 0.60))
        Behavior on color { ColorAnimation { duration: 130 } }
    }

    // Active outer glow
    Rectangle {
        visible: active
        anchors.fill: parent; anchors.margins: -4
        radius: parent.radius + 4; color: "transparent"
        border.color: Theme.accentDim; border.width: 1; z: -1
    }

    Text {
        id: lbl; anchors.centerIn: parent
        text: root.label
        font.pixelSize: 10; font.family: Theme.fontSans; font.weight: Font.Medium
        color: active ? Theme.pillActiveLbl : Theme.pillInactiveLbl
        Behavior on color { ColorAnimation { duration: 130 } }
    }

    scale: ma.pressed ? 0.88 : 1.0
    Behavior on scale { NumberAnimation { duration: 70; easing.type: Easing.OutBack } }

    MouseArea { id: ma; anchors.fill: parent; onClicked: root.clicked() }
}
