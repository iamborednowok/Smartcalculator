import QtQuick
import SmartCalc.Backend 1.0

// CalcButton v78
//  • All pixel sizes multiplied by Theme.scale → adapts to any screen size.
//  • Light-mode border uses full-white top sheen for a crisp "card" look.
//  • Dark press glow matches theme accent (teal dark, blue light).
//  • Multi-touch via TapHandler (unchanged from v77).
Rectangle {
    id: root
    property string label:   ""
    property string btnType: "normal"   // normal | op | eq | red | sci | dim
    signal clicked()

    // Scale-aware base heights
    readonly property real sciH:    Math.round(38 * Theme.scale)
    readonly property real normalH: Math.round(56 * Theme.scale)

    implicitHeight: btnType === "sci" ? sciH : normalH
    radius: btnType === "sci"
            ? Math.round(10 * Theme.scale)
            : Math.min(Math.round(20 * Theme.scale), height * 0.34)

    property int hitPad: btnType === "sci" ? Math.round(6 * Theme.scale) : 0

    // ── Drop shadow ───────────────────────────────────────────────────
    Rectangle {
        anchors { fill: parent; margins: -2; topMargin: 2 }
        z: -1; radius: parent.radius + 2
        color: {
            if (btnType === "eq")  return Qt.rgba(0,0.78,0.66, Theme.dark ? 0.28 : 0.16)
            if (btnType === "op")  return Qt.rgba(0,0.78,0.66, Theme.dark ? 0.16 : 0.10)
            if (btnType === "red") return Qt.rgba(0.96,0.25,0.37, Theme.dark ? 0.16 : 0.08)
            return Qt.rgba(0, 0, 0, Theme.dark ? 0.30 : 0.07)
        }
        opacity: tap.pressed ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 60 } }
    }

    // ── Background ────────────────────────────────────────────────────
    color: {
        switch (btnType) {
            case "eq":   return "transparent"
            case "op":   return Theme.btnOp
            case "red":  return Theme.btnRed
            case "sci":  return Theme.btnSci
            case "dim":  return Theme.btnDim
            default:     return Theme.btnNormal
        }
    }
    Behavior on color { ColorAnimation { duration: Theme.normal } }

    // ── Equals gradient ───────────────────────────────────────────────
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0;  color: btnType === "eq" ? Theme.eqA : "transparent" }
        GradientStop { position: 0.45; color: btnType === "eq" ? Theme.eqB : "transparent" }
        GradientStop { position: 1.0;  color: btnType === "eq" ? Theme.eqC : "transparent" }
    }

    // ── Border ────────────────────────────────────────────────────────
    border.color: {
        switch (btnType) {
            case "eq":  return Theme.bdrEq
            case "op":  return Theme.bdrOp
            case "red": return Theme.bdrRed
            case "sci": return Theme.bdrSci
            case "dim": return Theme.bdrDim
            default:    return Theme.bdrNormal
        }
    }
    border.width: 1
    Behavior on border.color { ColorAnimation { duration: Theme.normal } }

    // ── Top glass sheen ───────────────────────────────────────────────
    Rectangle {
        anchors {
            top: parent.top; left: parent.left; right: parent.right
            topMargin: 1
            leftMargin:  btnType === "sci" ? Math.round(4 * Theme.scale) : Math.round(6 * Theme.scale)
            rightMargin: btnType === "sci" ? Math.round(4 * Theme.scale) : Math.round(6 * Theme.scale)
        }
        height: 1; radius: parent.radius
        color: {
            if (btnType === "eq") return Qt.rgba(1, 1, 1, 0.32)
            return Theme.dark ? Qt.rgba(1, 1, 1, 0.11) : Qt.rgba(1, 1, 1, 0.95)
        }
        z: 2
        Behavior on color { ColorAnimation { duration: Theme.normal } }
    }

    // ── Ripple ────────────────────────────────────────────────────────
    Rectangle {
        id: ripple
        x: rippleX - width / 2;  y: rippleY - height / 2
        width: 0; height: width;  radius: width / 2
        color: btnType === "eq"  ? Qt.rgba(1,1,1,0.24)
             : btnType === "op"  ? (Theme.dark ? Qt.rgba(0,0.78,0.66,0.30) : Qt.rgba(0.36,0.69,0.96,0.28))
             : btnType === "red" ? Qt.rgba(0.96,0.25,0.37,0.28)
             : Qt.rgba(1,1,1,0.18)
        opacity: 0; z: 1; clip: false
        property real rippleX: root.width  / 2
        property real rippleY: root.height / 2
    }
    ParallelAnimation {
        id: rippleAnim
        NumberAnimation { target: ripple; property: "width"; to: root.width * 2.5
                          duration: 360; easing.type: Easing.OutQuart }
        SequentialAnimation {
            NumberAnimation { target: ripple; property: "opacity"; to: 1.0; duration: 20 }
            NumberAnimation { target: ripple; property: "opacity"; to: 0.0
                              duration: 340; easing.type: Easing.OutQuart }
        }
    }

    // ── Label ─────────────────────────────────────────────────────────
    Text {
        anchors.centerIn: parent; z: 3
        text: root.label
        color: {
            switch (root.btnType) {
                case "eq":  return Theme.lblEq
                case "op":  return Theme.lblOp
                case "red": return Theme.lblRed
                case "sci": return Theme.lblSci
                case "dim": return Theme.lblDim
                default:    return Theme.lblNormal
            }
        }
        font.pixelSize: root.btnType === "sci"
            ? Math.round(11 * Theme.scale)
            : root.btnType === "eq"
            ? Math.round(28 * Theme.scale)
            : Math.round(20 * Theme.scale)
        font.family: Theme.fontMono
        font.weight: root.btnType === "eq" ? Font.Light : Font.Normal
        renderType: Text.NativeRendering
        Behavior on color { ColorAnimation { duration: Theme.normal } }
    }

    // ── Press: scale spring + opacity dip ────────────────────────────
    scale:   tap.pressed ? 0.87 : 1.0
    opacity: tap.pressed ? 0.76 : 1.0
    Behavior on scale {
        NumberAnimation {
            duration: tap.pressed ? 65 : 260
            easing.type: Easing.OutBack
            easing.overshoot: tap.pressed ? 0 : 2.2
        }
    }
    Behavior on opacity { NumberAnimation { duration: 50 } }

    // ── TapHandler — multi-touch aware ────────────────────────────────
    TapHandler {
        id: tap
        gesturePolicy: TapHandler.ReleaseWithinBounds
        margin: -root.hitPad

        onPressedChanged: {
            if (pressed) {
                var pt = tap.point.position
                ripple.width   = 0
                ripple.opacity = 0
                ripple.rippleX = pt.x
                ripple.rippleY = pt.y
                rippleAnim.restart()

                if (root.btnType === "eq" || root.btnType === "red")
                    HapticHelper.heavy()
                else
                    HapticHelper.click()
            }
        }

        onTapped: root.clicked()
    }
}
