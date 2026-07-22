import QtQuick
import SmartCalc.Backend 1.0

// CalcButton v4 — "=" sweeps red→green→blue (Theme.gradA/B/C), neon glow
// rings in dark mode. Every other btnType keeps its original flat/2-tone
// look (see gradMid's midpoint-blend fallback below).
// btnType: digit | op | eq | func | clear
Item {
    id: root
    property string label:   ""
    property string btnType: "digit"
    signal clicked()

    implicitWidth:  Math.round(60 * Theme.scale)
    implicitHeight: Math.round(60 * Theme.scale)

    // ── Gradient colors per button type ──────────────────────────────
    readonly property color gradStart: {
        switch (btnType) {
            case "eq":    return Theme.gradA
            case "op":    return Theme.dark ? Theme.surfaceOp : Theme.surface2
            default:      return Theme.surface
        }
    }
    readonly property color gradEnd: {
        switch (btnType) {
            case "eq":    return Theme.gradC
            case "op":    return Theme.surface2
            default:      return gradStart   // flat = same both ends
        }
    }
    // Middle stop: only "eq" gets the true RGB sweep (red → green → blue).
    // Every other button type gets the exact midpoint blend of its own
    // start/end colors, which sits exactly on the gradStart→gradEnd line —
    // i.e. visually identical to a plain 2-stop gradient, just expressed
    // as three stops so one Gradient definition below covers every type.
    readonly property color gradMid: btnType === "eq"
        ? Theme.gradB
        : Qt.rgba((gradStart.r + gradEnd.r) / 2, (gradStart.g + gradEnd.g) / 2,
                  (gradStart.b + gradEnd.b) / 2, (gradStart.a + gradEnd.a) / 2)
    readonly property color labelColor: {
        switch (btnType) {
            case "eq":    return Theme.textOnAccent
            case "op":    return Theme.accent2
            case "clear": return Theme.accent
            case "func":  return Theme.textDim
            default:      return Theme.text
        }
    }

    // ── Glow rings (drawn before the button = rendered behind it) ─────
    // Two stacked rings: outer softer, inner stronger.
    // Visible only in dark mode on eq and op buttons.
    Rectangle {
        anchors.centerIn: parent
        width:  parent.width  + Math.round(20 * Theme.scale)
        height: parent.height + Math.round(20 * Theme.scale)
        radius: Theme.rLg + Math.round(10 * Theme.scale)
        color:  btnType === "eq" ? Theme.glowA2 : (btnType === "op" ? Theme.glowB2 : "transparent")
        visible: Theme.dark
    }
    Rectangle {
        anchors.centerIn: parent
        width:  parent.width  + Math.round(10 * Theme.scale)
        height: parent.height + Math.round(10 * Theme.scale)
        radius: Theme.rLg + Math.round(5 * Theme.scale)
        color:  btnType === "eq" ? Theme.glowA : (btnType === "op" ? Theme.glowB : "transparent")
        visible: Theme.dark
    }

    // ── Main button face ──────────────────────────────────────────────
    Rectangle {
        id: face
        anchors.fill: parent
        radius: Theme.rLg

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: root.gradStart }
            GradientStop { position: 0.5; color: root.gradMid   }
            GradientStop { position: 1.0; color: root.gradEnd   }
        }
    }

    // ── Label ─────────────────────────────────────────────────────────
    Text {
        anchors.centerIn: parent
        text: root.label
        font.family: Theme.fontMono
        font.weight: root.btnType === "eq" ? Font.DemiBold : Font.Normal
        font.pixelSize: root.btnType === "eq"
            ? Math.round(24 * Theme.scale)
            : Math.round(22 * Theme.scale)
        color: root.labelColor
        Behavior on color { ColorAnimation { duration: Theme.normal } }
    }

    // ── Press animation ───────────────────────────────────────────────
    // Asymmetric on purpose: pressing down is quick/plain (feels
    // responsive, not laggy), releasing bounces back with a slight
    // overshoot past 1.0 before settling — that overshoot is what reads
    // as "funky" rather than just a flat fade back to resting size.
    scale: 1.0
    opacity: tap.pressed ? 0.82 : 1.0
    Behavior on opacity { NumberAnimation { duration: Theme.press } }

    NumberAnimation {
        id: pressDownAnim
        target: root; property: "scale"; to: 0.94
        duration: Theme.press
        easing.type: Easing.OutQuad
    }
    NumberAnimation {
        id: releaseBounceAnim
        target: root; property: "scale"; to: 1.0
        duration: Theme.bounceDuration
        easing.type: Theme.bounceEasing
        easing.overshoot: Theme.bounceOvershoot
    }

    TapHandler {
        id: tap
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onPressedChanged: {
            if (pressed) {
                if (root.btnType === "eq" || root.btnType === "clear") HapticHelper.heavy()
                else HapticHelper.click()
                releaseBounceAnim.stop(); pressDownAnim.restart()
            } else {
                pressDownAnim.stop(); releaseBounceAnim.restart()
            }
        }
        onTapped: root.clicked()
    }
}
