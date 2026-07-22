import QtQuick

// ToastMessage v3 — flat pill, pops up with a little bounce + fades in,
// then a plain fade-out on the way back down (bounce reads fine arriving,
// but felt odd on the way out, so only the entrance got it).
Item {
    id: root

    function show(msg, ok) {
        label.text = msg
        bar.color  = ok ? Theme.text : Theme.accent
        label.color = ok ? Theme.bg : Theme.onAccent
        anim.restart()
    }

    Rectangle {
        id: bar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.sp6
        radius: Theme.rFull
        height: Math.round(40 * Theme.scale)
        width: label.implicitWidth + Theme.sp5 * 2
        opacity: 0
        y: Theme.sp4

        Text {
            id: label
            anchors.centerIn: parent
            font.family: Theme.fontSans
            font.weight: Font.Medium
            font.pixelSize: Math.round(13 * Theme.scale)
        }
    }

    SequentialAnimation {
        id: anim
        ParallelAnimation {
            NumberAnimation { target: bar; property: "opacity"; to: 1; duration: 160 }
            NumberAnimation {
                target: bar; property: "y"; to: 0
                duration: Theme.popDuration
                easing.type: Theme.popEasing; easing.overshoot: Theme.popOvershoot * 3
            }
        }
        PauseAnimation { duration: 1500 }
        ParallelAnimation {
            NumberAnimation { target: bar; property: "opacity"; to: 0; duration: 200 }
            NumberAnimation { target: bar; property: "y"; to: Theme.sp4; duration: 200 }
        }
    }
}
