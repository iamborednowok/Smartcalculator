import QtQuick

Item {
    id: root
    anchors.fill: parent
    z: 9999

    property string message: ""
    property bool   success: false

    function show(msg, isSuccess) {
        message = msg
        success = isSuccess || false
        bubble.opacity = 0
        bubble.y = root.height - 60
        slideAnim.restart()
    }

    Rectangle {
        id: bubble
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height - 80
        opacity: 0

        height: 46
        width: toastRow.implicitWidth + 56
        radius: 23

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Theme.toastBg0 }
            GradientStop { position: 1.0; color: Theme.toastBg1 }
        }

        border.color: root.success
            ? Qt.rgba(0.06, 0.73, 0.51, 0.60)
            : Qt.rgba(0.49, 0.23, 0.93, 0.55)
        border.width: 1

        // Top sheen
        Rectangle {
            anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.50; height: 1; y: 1; radius: 1
            color: Qt.rgba(1, 1, 1, 0.28)
        }

        // Outer glow halo
        Rectangle {
            anchors.fill: parent; anchors.margins: -7
            radius: parent.radius + 7; color: "transparent"
            border.color: root.success
                ? Qt.rgba(0.06, 0.73, 0.51, 0.22)
                : Qt.rgba(0.49, 0.23, 0.93, 0.22)
            border.width: 1; z: -1
        }

        Row {
            id: toastRow
            anchors.centerIn: parent
            spacing: 10

            // Status dot
            Item {
                width: 14; height: 14; anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.centerIn: parent; width: 8; height: 8; radius: 4
                    color: root.success ? Theme.green : Theme.accent2
                }
                Rectangle {
                    anchors.centerIn: parent; width: 14; height: 14; radius: 7
                    color: "transparent"
                    border.color: root.success ? Qt.rgba(0.06,0.73,0.51,0.40) : Qt.rgba(0.67,0.55,1.0,0.40)
                    border.width: 1
                }
            }

            Text {
                text: root.message
                color: root.success ? Theme.green : Theme.accent2
                font.pixelSize: 13; font.weight: Font.Medium; font.family: Theme.fontSans
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        SequentialAnimation {
            id: slideAnim
            ParallelAnimation {
                NumberAnimation { target: bubble; property: "opacity"; to: 1;                duration: 200; easing.type: Easing.OutQuad }
                NumberAnimation { target: bubble; property: "y";       to: root.height-108; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.0 }
            }
            PauseAnimation { duration: 2600 }
            ParallelAnimation {
                NumberAnimation { target: bubble; property: "opacity"; to: 0;                duration: 240 }
                NumberAnimation { target: bubble; property: "y";       to: root.height - 70; duration: 240; easing.type: Easing.InQuad }
            }
        }
    }
}
