import QtQuick

Rectangle {
    id: root
    property string label:   ""
    property string btnType: "normal"  // normal | op | eq | red | sci | dim
    signal clicked()

    height: btnType === "sci" ? 40 : 58
    radius: 20

    // ── Background per type ────────────────────────────────────────────
    color: {
        switch (btnType) {
            case "eq":   return "transparent"
            case "op":   return Qt.rgba(0.49, 0.23, 0.93, 0.18)
            case "red":  return Qt.rgba(0.96, 0.25, 0.37, 0.10)
            case "sci":  return Qt.rgba(0.02, 0.71, 0.83, 0.09)
            case "dim":  return Qt.rgba(1, 1, 1, 0.05)
            default:     return Qt.rgba(1, 1, 1, 0.065)
        }
    }

    // ── Gradient for equals ───────────────────────────────────────────
    gradient: btnType === "eq" ? Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: "#5B21B6" }
        GradientStop { position: 0.45; color: "#7C3AED" }
        GradientStop { position: 1.0;  color: "#9061FF" }
    } : null

    // ── Border ────────────────────────────────────────────────────────
    border.color: {
        switch (btnType) {
            case "eq":  return Qt.rgba(0.80, 0.60, 1.0, 0.35)
            case "op":  return Qt.rgba(0.67, 0.55, 1.0, 0.42)
            case "red": return Qt.rgba(0.96, 0.25, 0.37, 0.40)
            case "sci": return Qt.rgba(0.02, 0.71, 0.83, 0.32)
            case "dim": return Qt.rgba(1, 1, 1, 0.08)
            default:    return Qt.rgba(1, 1, 1, 0.09)
        }
    }
    border.width: 1

    // ── Outer glow halo ───────────────────────────────────────────────
    Rectangle {
        id: glowHalo
        anchors.fill: parent
        anchors.margins: -6
        radius: parent.radius + 6
        color: "transparent"
        border.color: {
            switch (btnType) {
                case "eq":  return Qt.rgba(0.49, 0.23, 0.93, 0.38)
                case "op":  return Qt.rgba(0.49, 0.23, 0.93, 0.16)
                case "red": return Qt.rgba(0.96, 0.25, 0.37, 0.18)
                default:    return "transparent"
            }
        }
        border.width: (btnType === "eq") ? 2 : 1
        z: -1
        visible: btnType === "eq" || btnType === "op" || btnType === "red"
    }

    // ── Top glass sheen ───────────────────────────────────────────────
    Rectangle {
        anchors.top:        parent.top
        anchors.left:       parent.left
        anchors.right:      parent.right
        anchors.topMargin:  1
        anchors.leftMargin: 5
        anchors.rightMargin: 5
        height: 1
        radius: parent.radius
        color: Qt.rgba(1, 1, 1, btnType === "eq" ? 0.32 : 0.12)
        z: 2
    }

    // ── Inner bottom shadow ───────────────────────────────────────────
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.bottomMargin: 1
        anchors.leftMargin:   5
        anchors.rightMargin:  5
        height: 1
        radius: parent.radius
        color: Qt.rgba(0, 0, 0, 0.30)
        z: 2
    }

    // ── Label ─────────────────────────────────────────────────────────
    Text {
        anchors.centerIn: parent
        text: root.label
        color: {
            switch (root.btnType) {
                case "eq":  return "#ffffff"
                case "op":  return "#C4B5FD"
                case "red": return "#FDA4AF"
                case "sci": return "#67E8F9"
                case "dim": return "#8888cc"
                default:    return "#f0f0ff"
            }
        }
        font.pixelSize: root.btnType === "sci" ? 11 :
                        root.btnType === "eq"  ? 24 : 18
        font.family: "DM Mono"
        font.weight: root.btnType === "eq" ? Font.Bold : Font.Normal
        renderType: Text.NativeRendering
    }

    // ── Press feedback ────────────────────────────────────────────────
    scale:   ma.pressed ? 0.82 : 1.0
    opacity: ma.pressed ? 0.68 : 1.0
    Behavior on scale {
        NumberAnimation {
            duration: 60
            easing.type: Easing.OutBack
            easing.overshoot: 3.0
        }
    }
    Behavior on opacity { NumberAnimation { duration: 60 } }

    MouseArea { id: ma; anchors.fill: parent; onClicked: root.clicked() }
}
