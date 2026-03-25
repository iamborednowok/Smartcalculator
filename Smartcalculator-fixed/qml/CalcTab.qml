import QtQuick
import QtQuick.Layouts
import "components"

Item {
    id: root

    property string expr:      ""
    property string prevExpr:  ""
    property bool   justEval:  false
    property string calcType:  "basic"
    property string angleMode: "deg"
    property bool   fracMode:  false
    property bool   showHist:  false

    property string displayVal: expr === "" ? "0" : expr
    property int parenBalance: {
        var n = 0
        for (var i = 0; i < expr.length; i++) {
            if (expr[i] === "(") n++
            else if (expr[i] === ")") n--
        }
        return Math.max(0, n)
    }

    function displayFmt(v) {
        if (v === "Error" || v === "0" || v.indexOf("/") >= 0) return v
        var num = parseFloat(v)
        if (!isFinite(num)) return v
        var parts = v.split(".")
        parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",")
        return parts.join(".")
    }
    function displaySize(v) {
        if (v.length > 18) return 14
        if (v.length > 13) return 19
        if (v.length > 9)  return 27
        return 38
    }

    // ── BUG FIX: x², xʸ, n! now handled correctly ────────────────────
    function handleBtn(val) {
        if (val === "C")  { expr = ""; prevExpr = ""; justEval = false; return }
        if (val === "⌫")  {
            if (justEval) { expr = ""; justEval = false; return }
            expr = expr.length > 1 ? expr.slice(0, -1) : ""; return
        }
        if (val === "±")  { expr = expr.startsWith("-") ? expr.slice(1) : (expr ? "-" + expr : ""); justEval = false; return }
        if (val === "%")  { var pct = parseFloat(expr); if (!isNaN(pct)) { expr = mathEngine.formatNumber(pct / 100); justEval = false }; return }

        // BUG FIX: sci special buttons
        if (val === "x²") {
            // Wrap current expression in parens then square it
            expr = expr ? "(" + expr + ")^2" : ""
            justEval = false; return
        }
        if (val === "xʸ") {
            // Append ^ so user types exponent next
            if (expr) expr += "^"
            justEval = false; return
        }
        if (val === "n!") {
            // Wrap in fact()
            if (expr) expr = "fact(" + expr + ")"
            justEval = false; return
        }

        if (val === "=")  {
            var t = expr || "0"
            var r = mathEngine.evaluate(t, angleMode === "deg", fracMode)
            prevExpr = t + " ="; expr = r; justEval = true
            flashAnim.restart()
            window.addHistory(t, r)
            return
        }
        var isOp = ["+","−","×","÷","^"].indexOf(val) >= 0
        if (justEval) { expr = isOp ? expr + val : val; justEval = false; return }
        if (val === "." && /\.\d*$/.test(expr)) return
        if (val === "." && (expr === "" || isOp)) expr += "0"
        expr += val
    }

    readonly property var sciRows: [
        ["sin(","cos(","tan(",   "("],
        ["log(","ln(",  "√(",    ")"],
        ["x²",  "xʸ",  "π",    "e"],
        ["sinh(","n!","nCr(","nPr("]
    ]
    readonly property var basicRows: [
        ["C",  "±",  "%",  "÷"],
        ["7",  "8",  "9",  "×"],
        ["4",  "5",  "6",  "−"],
        ["1",  "2",  "3",  "+"],
        ["0",  ".",  "⌫",  "="]
    ]

    function btnType(lbl) {
        if (lbl === "=")   return "eq"
        if (["+","−","×","÷","^"].indexOf(lbl) >= 0) return "op"
        if (lbl === "C")   return "red"
        if (["±","%","⌫"].indexOf(lbl) >= 0) return "dim"
        return "normal"
    }

    property var window: ApplicationWindow.window

    // ──────────────────────────────────────────────────────────────────
    Flickable {
        anchors.fill: parent
        anchors.margins: 16
        contentHeight: mainCol.implicitHeight
        clip: true

        ColumnLayout {
            id: mainCol
            width: parent.width
            spacing: 10

            // ── Header ───────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true

                Column {
                    spacing: 2
                    Row {
                        spacing: 0
                        Text {
                            text: "Smart"
                            font.pixelSize: 22; font.family: "DM Sans"
                            font.weight: Font.Light; color: "#8888cc"
                        }
                        Text {
                            text: "Calc"
                            font.pixelSize: 22; font.family: "DM Sans"
                            font.weight: Font.Bold; color: "#A78BFA"
                        }
                    }
                    // Cyan accent underline
                    Rectangle {
                        width: 44; height: 2; radius: 1
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#7C3AED" }
                            GradientStop { position: 1.0; color: "#06B6D4" }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Mode badge
                Rectangle {
                    height: 28; width: modeLbl.implicitWidth + 22; radius: 14
                    color: calcType === "sci"
                        ? Qt.rgba(0.02, 0.71, 0.83, 0.12)
                        : Qt.rgba(0.49, 0.23, 0.93, 0.12)
                    border.color: calcType === "sci"
                        ? Qt.rgba(0.02, 0.71, 0.83, 0.38)
                        : Qt.rgba(0.49, 0.23, 0.93, 0.30)
                    border.width: 1
                    Text {
                        id: modeLbl; anchors.centerIn: parent
                        text: calcType === "sci" ? "SCI" : "BASIC"
                        font.pixelSize: 9; font.family: "DM Sans"; font.weight: Font.Bold
                        font.letterSpacing: 0.8
                        color: calcType === "sci" ? "#06B6D4" : "#A78BFA"
                    }
                    MouseArea { anchors.fill: parent; onClicked: calcType = calcType === "sci" ? "basic" : "sci" }
                }

                // Settings / info button
                Rectangle {
                    width: 34; height: 34; radius: 11
                    color: Qt.rgba(1, 1, 1, 0.055)
                    border.color: Qt.rgba(1, 1, 1, 0.10); border.width: 1
                    Rectangle {
                        anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
                        width: 20; height: 1; y: 2; radius: 1
                        color: Qt.rgba(1, 1, 1, 0.18)
                    }
                    Text { anchors.centerIn: parent; text: "☀️"; font.pixelSize: 14 }
                    MouseArea { anchors.fill: parent; onClicked: window.showToast("Dark mode only ✦ premium", false) }
                }
            }

            // ── Display panel ─────────────────────────────────────────
            Rectangle {
                id: displayRect
                Layout.fillWidth: true
                height: 128
                radius: 24

                // Glass base
                color: Qt.rgba(1, 1, 1, 0.04)

                // Animated border
                border.color: bdColorAnim.currentColor
                border.width: 1

                QtObject {
                    id: bdColorAnim
                    property color currentColor: Qt.rgba(1, 1, 1, 0.10)
                }
                SequentialAnimation {
                    id: flashAnim
                    ColorAnimation {
                        target: bdColorAnim; property: "currentColor"
                        to: "#06B6D4"; duration: 80
                    }
                    ColorAnimation {
                        target: bdColorAnim; property: "currentColor"
                        to: Qt.rgba(1, 1, 1, 0.10); duration: 550
                    }
                }

                // Top sheen
                Rectangle {
                    anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width * 0.55; height: 1; y: 1; radius: 1
                    color: Qt.rgba(1, 1, 1, 0.20)
                }

                // Bottom fade
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left; anchors.right: parent.right
                    height: 44; radius: parent.radius
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.28) }
                    }
                }

                // Outer glow ring
                Rectangle {
                    anchors.fill: parent; anchors.margins: -7
                    radius: parent.radius + 7
                    color: "transparent"
                    border.color: Qt.rgba(0.49, 0.23, 0.93, 0.10); border.width: 1; z: -1
                }

                // Paren open badge
                Rectangle {
                    visible: parenBalance > 0
                    anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 14
                    height: 22; width: pbTxt.implicitWidth + 18; radius: 11
                    color: Qt.rgba(0.95, 0.62, 0.07, 0.10)
                    border.color: Qt.rgba(0.95, 0.62, 0.07, 0.35); border.width: 1
                    Text {
                        id: pbTxt; anchors.centerIn: parent
                        text: "( ×" + parenBalance
                        font.pixelSize: 9; color: "#F59E0B"; font.family: "DM Mono"
                    }
                }

                // Copy button
                Rectangle {
                    visible: displayVal !== "0" && displayVal !== "Error"
                    anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 14
                    height: 24; width: cpLbl.implicitWidth + 18; radius: 12
                    color: cpDone ? Qt.rgba(0.06,0.73,0.51,0.12) : Qt.rgba(1, 1, 1, 0.06)
                    border.color: cpDone ? Qt.rgba(0.06,0.73,0.51,0.32) : Qt.rgba(1, 1, 1, 0.12); border.width: 1
                    property bool cpDone: false
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text {
                        id: cpLbl; anchors.centerIn: parent
                        text: parent.cpDone ? "✓ copied" : "copy"
                        font.pixelSize: 9; font.family: "DM Sans"
                        color: parent.cpDone ? "#10B981" : "#44446a"
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { parent.cpDone = true; cpTimer.restart() }
                    }
                    Timer { id: cpTimer; interval: 1800; onTriggered: parent.cpDone = false }
                }

                // Number + cursor
                Column {
                    anchors.right: parent.right; anchors.bottom: parent.bottom
                    anchors.rightMargin: 18; anchors.bottomMargin: 14
                    spacing: 5

                    Text {
                        anchors.right: parent.right
                        text: prevExpr; font.pixelSize: 11; font.family: "DM Mono"
                        color: "#33335a"
                    }

                    Row {
                        anchors.right: parent.right; spacing: 2

                        Text {
                            id: mainNumber
                            text: displayFmt(displayVal)
                            color: displayVal === "Error" ? "#F43F5E" : "#f0f0ff"
                            font.pixelSize: displaySize(displayVal)
                            font.family: "DM Mono"; font.weight: Font.Light
                            Behavior on font.pixelSize { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        // Blinking cursor
                        Rectangle {
                            visible: !justEval
                            width: 2.5
                            height: Math.max(displaySize(displayVal) * 0.72, 16)
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 2
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#7C3AED" }
                                GradientStop { position: 1.0; color: "#06B6D4" }
                            }
                            SequentialAnimation on opacity {
                                running: true; loops: Animation.Infinite
                                NumberAnimation { to: 0; duration: 530; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1; duration: 530; easing.type: Easing.InOutSine }
                            }
                        }
                    }
                }

                DragHandler {
                    target: null
                    xAxis.minimum: -200; xAxis.maximum: 0
                    onActiveChanged: { if (!active && xAxis.activeValue < -40) handleBtn("⌫") }
                }
            }

            // ── Mode pill row ─────────────────────────────────────────
            RowLayout { Layout.fillWidth: true; spacing: 6

                // DEG / RAD (only in sci mode)
                Rectangle {
                    visible: calcType === "sci"
                    height: 28; width: 56; radius: 14
                    color: Qt.rgba(0.02, 0.71, 0.83, angleMode === "deg" ? 0.14 : 0.06)
                    border.color: Qt.rgba(0.02, 0.71, 0.83, angleMode === "deg" ? 0.40 : 0.14)
                    border.width: 1
                    Text {
                        anchors.centerIn: parent; text: angleMode.toUpperCase()
                        font.pixelSize: 9; font.family: "DM Sans"; font.weight: Font.Bold
                        color: angleMode === "deg" ? "#06B6D4" : "#44446a"
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    MouseArea { anchors.fill: parent; onClicked: angleMode = angleMode === "deg" ? "rad" : "deg" }
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                // ½ frac toggle
                Rectangle {
                    height: 28; width: 56; radius: 14
                    color: fracMode ? Qt.rgba(0.95,0.62,0.07,0.14) : Qt.rgba(1,1,1,0.05)
                    border.color: fracMode ? Qt.rgba(0.95,0.62,0.07,0.42) : Qt.rgba(1,1,1,0.09)
                    border.width: 1
                    Text {
                        anchors.centerIn: parent; text: "½ frac"
                        font.pixelSize: 9; font.family: "DM Sans"
                        color: fracMode ? "#F59E0B" : "#44446a"
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    MouseArea { anchors.fill: parent; onClicked: fracMode = !fracMode }
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                Item { Layout.fillWidth: true }

                // History pill
                Rectangle {
                    height: 28; width: histLbl.implicitWidth + 20; radius: 14
                    color: showHist ? Qt.rgba(0.49,0.23,0.93,0.18) : Qt.rgba(1,1,1,0.05)
                    border.color: showHist ? Qt.rgba(0.67,0.55,1.0,0.40) : Qt.rgba(1,1,1,0.09)
                    border.width: 1
                    Text {
                        id: histLbl; anchors.centerIn: parent
                        text: "Hist" + (window && window.calcHistory.length > 0 ? " (" + window.calcHistory.length + ")" : "")
                        font.pixelSize: 9; font.family: "DM Sans"
                        color: showHist ? "#A78BFA" : "#44446a"
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    MouseArea { anchors.fill: parent; onClicked: showHist = !showHist }
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
            }

            // ── History panel ─────────────────────────────────────────
            Rectangle {
                visible: showHist && window && window.calcHistory.length > 0
                Layout.fillWidth: true
                height: visible ? Math.min(histView.contentHeight + 52, 196) : 0
                radius: 20
                color: Qt.rgba(0, 0, 0, 0.30)
                border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1
                clip: true
                Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutQuart } }

                Rectangle {
                    anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width * 0.40; height: 1; y: 1; radius: 1
                    color: Qt.rgba(1,1,1,0.10)
                }

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 7

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "HISTORY"; font.pixelSize: 8; color: "#33335a"; font.letterSpacing: 1.2; font.family: "DM Sans" }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "clear all"; font.pixelSize: 8; color: "#44446a"; font.family: "DM Sans"
                            MouseArea { anchors.fill: parent; onClicked: { window.calcHistory = []; showHist = false } }
                        }
                    }

                    ListView {
                        id: histView
                        Layout.fillWidth: true; Layout.fillHeight: true
                        model: window ? window.calcHistory : []
                        clip: true; spacing: 2

                        delegate: Rectangle {
                            width: histView.width; height: 34; radius: 10
                            color: "transparent"
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                                Text { text: modelData.expr; color: "#666688"; font.pixelSize: 10; font.family: "DM Mono"; Layout.fillWidth: true; elide: Text.ElideRight }
                                Text { text: modelData.result; color: "#A78BFA"; font.pixelSize: 13; font.family: "DM Mono"; font.weight: Font.Light }
                                Text { text: modelData.time; color: "#33335a"; font.pixelSize: 8; leftPadding: 8; font.family: "DM Sans" }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: { expr = modelData.result; justEval = true; showHist = false }
                                onPressed:  parent.color = Qt.rgba(1,1,1,0.05)
                                onReleased: parent.color = "transparent"
                            }
                        }
                    }
                }
            }

            // ── Scientific rows ───────────────────────────────────────
            Repeater {
                model: calcType === "sci" ? sciRows : []
                delegate: Row {
                    spacing: 6
                    Repeater {
                        model: modelData
                        delegate: CalcButton {
                            label: modelData; btnType: "sci"
                            width: (mainCol.width - 18) / 4
                            onClicked: handleBtn(label)
                        }
                    }
                }
            }

            // Thin separator before basic grid (in sci mode)
            Rectangle {
                visible: calcType === "sci"
                Layout.fillWidth: true; height: 1
                color: Qt.rgba(1,1,1,0.06)
            }

            // ── Basic grid ────────────────────────────────────────────
            Repeater {
                model: basicRows
                delegate: Row {
                    spacing: 6
                    Repeater {
                        model: modelData
                        delegate: CalcButton {
                            label: modelData
                            btnType: root.btnType(modelData)
                            width: (mainCol.width - 18) / 4
                            onClicked: handleBtn(label)
                        }
                    }
                }
            }

            // ── Keyboard hint ─────────────────────────────────────────
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "⌨  0–9 · +-×÷ · Enter · Esc · Backspace"
                font.pixelSize: 8; font.family: "DM Sans"
                color: "#22223c"; font.letterSpacing: 0.3
            }

            Item { height: 4 }
        }
    }

    Keys.onPressed: function(event) {
        var map = { "Return":"=","Enter":"=","Backspace":"⌫","Escape":"C",
                    "+":"+","-":"−","*":"×","/":"÷","(":"(",")":")","^":"^","%":"%",".":"." }
        if (map[event.key]) { handleBtn(map[event.key]); event.accepted = true }
        else if (event.text >= "0" && event.text <= "9") { handleBtn(event.text); event.accepted = true }
    }
    focus: visible
}
