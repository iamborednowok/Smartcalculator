import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import SmartCalc.Backend 1.0
import "components"

Item {
    id: root

    property string expr:      ""
    property string prevExpr:  ""
    property bool   justEval:  false
    property string angleMode: "deg"
    property bool   fracMode:  false
    property bool   showHist:  false
    property bool   sciOpen:   false
    property bool   sciMode:   false
    property bool   showVars:  false
    property bool   showAssign: false          // letter-picker for assignment

    // Variable store — persisted in session
    property var variables: ({})

    property string displayVal: expr === "" ? "0" : expr
    property int parenBalance: {
        var n = 0
        for (var i = 0; i < expr.length; i++) {
            if (expr[i] === "(") n++
            else if (expr[i] === ")") n--
        }
        return Math.max(0, n)
    }

    property var window: ApplicationWindow.window

    // ── Sci strip buttons ─────────────────────────────────────────────
    readonly property var sciStrip: [
        "sin(","cos(","tan(","log(","ln(","√(","(",")", "x²","xʸ","π","e","n!","nCr(","nPr(","sinh("
    ]

    readonly property var numRows: [
        ["7","8","9"],
        ["4","5","6"],
        ["1","2","3"],
        ["C","0","⌫"]
    ]
    readonly property var opCol: ["÷","×","−","+"]

    // ── Syntax highlighter ────────────────────────────────────────────
    function highlightExpr(v) {
        if (!v || v === "Error" || /^-?[\d,]+\.?\d*$/.test(v)) return v
        // Escape for HTML first
        var safe = v.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;")
        // Functions → cyan
        safe = safe.replace(/(sin|cos|tan|log|ln|sqrt|fact|nCr|nPr|sinh|cosh|tanh|abs)(?=\()/g,
                            '<font color="#67E8F9">$1</font>')
        // Operators → soft purple
        safe = safe.replace(/([\+\-×÷\^%])/g, '<font color="#C4B5FD">$1</font>')
        // Parens — yellow
        safe = safe.replace(/\(/g, '<font color="#F59E0B">(</font>')
        safe = safe.replace(/\)/g, '<font color="#F59E0B">)</font>')
        // Constants → green
        safe = safe.replace(/\bπ\b/g, '<font color="#10B981">π</font>')
        safe = safe.replace(/\be\b/g,  '<font color="#10B981">e</font>')
        return safe
    }

    function displayFmt(v) {
        if (v === "Error" || v === "0" || v.indexOf("/") >= 0) return v
        var num = parseFloat(v)
        if (!isFinite(num)) return v
        var parts = v.split(".")
        parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",")
        return parts.join(".")
    }

    function displayFontSize(v) {
        // FIX: scale with Theme.scale so display font is correct on all screen sizes
        var base
        if (v.length > 18) base = 15
        else if (v.length > 13) base = 20
        else if (v.length > 9)  base = 28
        else base = 38
        return Math.round(base * Theme.scale)
    }

    function btnType(lbl) {
        if (lbl === "=")   return "eq"
        if (["+","−","×","÷","^"].indexOf(lbl) >= 0) return "op"
        if (lbl === "C")   return "red"
        if (["±","%","⌫"].indexOf(lbl) >= 0) return "dim"
        return "normal"
    }

    function handleBtn(val) {
        if (val === "C")  { expr = ""; prevExpr = ""; justEval = false; showAssign = false; return }
        if (val === "⌫")  {
            if (justEval) { expr = ""; justEval = false; return }
            expr = expr.length > 1 ? expr.slice(0, -1) : ""
            return
        }
        if (val === "±")  { expr = expr.startsWith("-") ? expr.slice(1) : (expr ? "-" + expr : ""); justEval = false; return }
        if (val === "%")  {
            var pct = parseFloat(expr)
            if (!isNaN(pct)) { expr = mathEngine.formatNumber(pct / 100); justEval = false }
            return
        }
        if (val === "x²") { if (expr) expr = "(" + expr + ")^2"; justEval = false; return }
        if (val === "xʸ") { if (expr) expr += "^"; justEval = false; return }
        if (val === "n!") { if (expr) expr = "fact(" + expr + ")"; justEval = false; return }

        if (val === "=") {
            var t = expr || "0"
            // Substitute variables in expression
            t = substituteVars(t)
            var r = mathEngine.evaluate(t, angleMode === "deg", fracMode)
            prevExpr = expr + " ="; expr = r; justEval = true; showAssign = (r !== "Error")
            flashAnim.restart()
            numPopAnim.restart()
            if (window) window.addHistory(t, r)
            return
        }
        var isOp = ["+","−","×","÷","^"].indexOf(val) >= 0
        if (justEval) { expr = isOp ? expr + val : val; justEval = false; showAssign = false; return }
        if (val === "." && /\.\d*$/.test(expr)) return
        if (val === ".") {
            var lastCh = expr.length > 0 ? expr[expr.length - 1] : ""
            if (expr === "" || ["+","−","×","÷","^","("].indexOf(lastCh) >= 0) expr += "0"
        }
        expr += val
        showAssign = false
    }

    // Expand stored variables in expression text
    function substituteVars(t) {
        for (var k in variables) {
            var re = new RegExp("\\b" + k + "\\b", "g")
            t = t.replace(re, "(" + variables[k] + ")")
        }
        return t
    }

    function assignToVar(letter) {
        if (!justEval || expr === "Error") return
        variables[letter] = expr
        variables = variables    // trigger binding update
        showAssign = false
        if (window) window.showToast(letter + " = " + expr, true)
    }

    // ── Clipboard helper (hidden) ─────────────────────────────────────
    TextEdit { id: clipHelper; visible: false; text: "" }
    function copyToClipboard(t) { clipHelper.text = t; clipHelper.selectAll(); clipHelper.copy() }

    // ── UI ────────────────────────────────────────────────────────────
    // Outer ColumnLayout: top display section scrolls independently when
    // history / variable panels expand; button grid fills remaining space.
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 7
        anchors.bottomMargin: 4
        spacing: 4

    // ── Scrollable top section ────────────────────────────────────────
    Flickable {
        id: topFlick
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, root.height * 0.48)
        contentHeight: topCol.implicitHeight
        clip: true
        flickableDirection: Flickable.VerticalFlick

        ColumnLayout {
            id: topCol
            width: parent.width
            spacing: 8

            // ── Header ────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true

                Row {
                    spacing: 0
                    Text { text: "Smart"; font.pixelSize: Math.round(16 * Theme.scale); font.family: Theme.fontSans; font.weight: Font.Light; color: Theme.text2; Behavior on color { ColorAnimation { duration: Theme.normal } } }
                    Text { text: "Calc"; font.pixelSize: Math.round(16 * Theme.scale); font.family: Theme.fontSans; font.weight: Font.Bold; color: Theme.accent2; Behavior on color { ColorAnimation { duration: Theme.normal } } }
                    Rectangle { width: 6; height: 6; radius: 3; color: Theme.cyan; anchors.verticalCenter: parent.verticalCenter; anchors.leftMargin: 2
                        Rectangle { anchors.centerIn: parent; width: 12; height: 12; radius: 6; color: "transparent"; border.color: Theme.cyan; border.width: 1; opacity: 0.45 }
                        Behavior on color { ColorAnimation { duration: Theme.normal } }
                    }
                }

                Item { Layout.fillWidth: true }

                // Angle mode (sci only) — FIX: was `sciMode` (never set), corrected to `sciOpen`
                Rectangle {
                    visible: sciOpen; height: 24; width: 50; radius: 12
                    color: Qt.rgba(0.02, 0.71, 0.83, angleMode === "deg" ? (Theme.dark ? 0.15 : 0.12) : (Theme.dark ? 0.06 : 0.04))
                    border.color: Qt.rgba(0.02, 0.71, 0.83, angleMode === "deg" ? 0.42 : 0.14); border.width: 1
                    Text { anchors.centerIn: parent; text: angleMode.toUpperCase(); font.pixelSize: Math.round(9 * Theme.scale); font.family: Theme.fontSans; font.weight: Font.Bold; color: angleMode === "deg" ? Theme.cyan : Theme.text3; Behavior on color { ColorAnimation { duration: 120 } } }
                    MouseArea { anchors.fill: parent; onClicked: angleMode = angleMode === "deg" ? "rad" : "deg" }
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                // ½ Frac toggle
                Rectangle {
                    height: 24; width: 52; radius: 12
                    color: fracMode ? Qt.rgba(0.95,0.62,0.07, Theme.dark ? 0.14 : 0.10) : Theme.actionBg
                    border.color: fracMode ? Qt.rgba(0.95,0.62,0.07,0.42) : Theme.actionBdr; border.width: 1
                    Text { anchors.centerIn: parent; text: "½ frac"; font.pixelSize: Math.round(9 * Theme.scale); font.family: Theme.fontSans; color: fracMode ? "#F59E0B" : Theme.text3; Behavior on color { ColorAnimation { duration: 120 } } }
                    MouseArea { anchors.fill: parent; onClicked: fracMode = !fracMode }
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                // Var manager button
                Rectangle {
                    height: 26; width: varBtnLbl.implicitWidth + 14; radius: 13
                    color: showVars ? Theme.accentDim : Theme.actionBg
                    border.color: showVars ? Theme.accent : Theme.actionBdr; border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text { id: varBtnLbl; anchors.centerIn: parent; text: "VAR" + (Object.keys(variables).length > 0 ? " (" + Object.keys(variables).length + ")" : ""); font.pixelSize: Math.round(9 * Theme.scale); font.family: Theme.fontSans; font.weight: Font.Bold; color: showVars ? Theme.accent2 : Theme.text3; Behavior on color { ColorAnimation { duration: 150 } } }
                    MouseArea { anchors.fill: parent; onClicked: showVars = !showVars }
                }

                // NOTE: Dark mode toggle is in the main app header — not duplicated here
            }

            // ── Variable manager drawer ────────────────────────────────
            Rectangle {
                visible: showVars
                Layout.fillWidth: true
                height: visible ? varCol.implicitHeight + 24 : 0
                clip: true; radius: 16
                color: Theme.sectionBg; border.color: Theme.sectionBdr; border.width: 1
                Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutQuart } }
                Behavior on color  { ColorAnimation { duration: Theme.normal } }

                ColumnLayout {
                    id: varCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "VARIABLES"; font.pixelSize: Math.round(8 * Theme.scale); color: Theme.text3; font.letterSpacing: 1.2; font.family: Theme.fontSans; Behavior on color { ColorAnimation { duration: Theme.normal } } }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "clear all"; font.pixelSize: Math.round(8 * Theme.scale); color: Theme.text3; font.family: Theme.fontSans
                            MouseArea { anchors.fill: parent; onClicked: { variables = {} } }
                        }
                    }

                    // Variable chips
                    Flow {
                        Layout.fillWidth: true; spacing: 6
                        Repeater {
                            model: Object.keys(variables)
                            delegate: Rectangle {
                                height: 28; width: chipLbl.implicitWidth + 20; radius: 10
                                gradient: Gradient { orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: Qt.rgba(0.49,0.23,0.93,0.20) }
                                    GradientStop { position: 1.0; color: Qt.rgba(0.02,0.71,0.83,0.16) } }
                                border.color: Qt.rgba(0.67,0.55,1.0,0.35); border.width: 1
                                Text { id: chipLbl; anchors.centerIn: parent; text: modelData + " = " + variables[modelData]; font.pixelSize: Math.round(11 * Theme.scale); font.family: Theme.fontMono; color: Theme.accent2 }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: { expr = (justEval ? "" : expr) + modelData; justEval = false }
                                    onPressAndHold: {
                                        var v = Object.assign({}, variables)
                                        delete v[modelData]
                                        variables = v
                                    }
                                }
                            }
                        }
                    }

                    // Empty hint
                    Text {
                        visible: Object.keys(variables).length === 0
                        text: "No variables yet. Press = then tap → var to assign a result."
                        color: Theme.text3; font.pixelSize: Math.round(10 * Theme.scale); wrapMode: Text.WordWrap
                        Layout.fillWidth: true; font.family: Theme.fontSans
                    }
                }
            }

            // ── Display card ──────────────────────────────────────────
            Rectangle {
                id: displayRect
                Layout.fillWidth: true
                height: 80
                radius: 18
                color: Theme.displayBg
                Behavior on color { ColorAnimation { duration: Theme.normal } }

                border.color: bdColorAnim.currentColor; border.width: 1

                QtObject {
                    id: bdColorAnim
                    property color currentColor: Theme.displayBdr
                }
                SequentialAnimation {
                    id: flashAnim
                    ColorAnimation { target: bdColorAnim; property: "currentColor"; to: Theme.cyan;       duration: 75 }
                    ColorAnimation { target: bdColorAnim; property: "currentColor"; to: Theme.displayBdr; duration: 700 }
                }

                // Top sheen
                Rectangle {
                    anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width * 0.52; height: 1; y: 1; radius: 1
                    color: Theme.borderTop; Behavior on color { ColorAnimation { duration: Theme.normal } }
                }
                // Bottom fade
                Rectangle {
                    anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
                    height: 42; radius: parent.radius
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, Theme.dark ? 0.22 : 0.04) }
                    }
                }

                // Paren balance badge
                Rectangle {
                    visible: parenBalance > 0
                    anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 12
                    height: 20; width: pbTxt.implicitWidth + 16; radius: 10
                    color: Qt.rgba(0.95, 0.62, 0.07, Theme.dark ? 0.10 : 0.08)
                    border.color: Qt.rgba(0.95, 0.62, 0.07, 0.32); border.width: 1
                    Text { id: pbTxt; anchors.centerIn: parent; text: "( ×" + parenBalance; font.pixelSize: Math.round(9 * Theme.scale); color: "#F59E0B"; font.family: Theme.fontMono }
                }

                // Copy button
                Rectangle {
                    visible: displayVal !== "0" && displayVal !== "Error"
                    anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 10
                    height: 22; width: cpLbl.implicitWidth + 16; radius: 11
                    color: cpDone ? Qt.rgba(0.06,0.73,0.51, Theme.dark ? 0.12 : 0.10) : Theme.actionBg
                    border.color: cpDone ? Qt.rgba(0.06,0.73,0.51,0.32) : Theme.actionBdr; border.width: 1
                    property bool cpDone: false
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text { id: cpLbl; anchors.centerIn: parent; text: parent.cpDone ? "✓ copied" : "copy"; font.pixelSize: Math.round(9 * Theme.scale); font.family: Theme.fontSans; color: parent.cpDone ? Theme.green : Theme.text3; Behavior on color { ColorAnimation { duration: 150 } } }
                    MouseArea { anchors.fill: parent; onClicked: { copyToClipboard(justEval ? expr : displayFmt(displayVal)); parent.cpDone = true; cpTimer.restart() } }
                    Timer { id: cpTimer; interval: 1800; onTriggered: parent.cpDone = false }
                }

                // History pill
                Rectangle {
                    anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.margins: 10
                    height: 22; width: histLbl.implicitWidth + 14; radius: 11
                    color: showHist ? Theme.accentDim : Theme.actionBg
                    border.color: showHist ? Theme.accent : Theme.actionBdr; border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text { id: histLbl; anchors.centerIn: parent; text: "Hist" + (window && window.calcHistory.length > 0 ? " (" + window.calcHistory.length + ")" : ""); font.pixelSize: Math.round(9 * Theme.scale); font.family: Theme.fontSans; color: showHist ? Theme.accent2 : Theme.text3; Behavior on color { ColorAnimation { duration: 150 } } }
                    MouseArea { anchors.fill: parent; onClicked: showHist = !showHist }
                }

                // Prev expression
                Text {
                    anchors.right: parent.right; anchors.bottom: mainNumber.top
                    anchors.rightMargin: 16; anchors.bottomMargin: 2
                    text: prevExpr; font.pixelSize: Math.round(11 * Theme.scale); font.family: Theme.fontMono
                    color: Theme.text3; opacity: prevExpr ? 1 : 0
                    Behavior on color   { ColorAnimation { duration: Theme.normal } }
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }

                // Highlighted expression overlay (shown while typing a complex expr)
                Text {
                    visible: !justEval && expr.length > 1
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.bottom: mainNumber.top
                    anchors.leftMargin: 16; anchors.rightMargin: 60; anchors.bottomMargin: 0
                    text: highlightExpr(expr)
                    textFormat: Text.RichText
                    font.pixelSize: Math.round(10 * Theme.scale); font.family: Theme.fontMono
                    color: Theme.text2; elide: Text.ElideLeft
                    opacity: justEval ? 0 : 0.85
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                }

                // Main number + cursor
                Row {
                    id: mainNumber
                    anchors.right: parent.right; anchors.bottom: parent.bottom
                    anchors.rightMargin: 16; anchors.bottomMargin: 8
                    spacing: 2

                    Text {
                        text: displayFmt(displayVal)
                        color: displayVal === "Error" ? Theme.red : Theme.text
                        font.pixelSize: displayFontSize(displayVal)
                        font.family: Theme.fontMono; font.weight: Font.Light
                        Behavior on font.pixelSize { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    transform: Scale {
                        id: numScale
                        origin.x: mainNumber.width / 2; origin.y: mainNumber.height / 2
                        xScale: 1.0; yScale: 1.0
                    }

                    // Blinking cursor
                    Rectangle {
                        visible: !justEval
                        width: 2.5
                        height: Math.max(displayFontSize(displayVal) * 0.68, 16)
                        anchors.verticalCenter: parent.verticalCenter; radius: 2
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.accent }
                            GradientStop { position: 1.0; color: Theme.cyan }
                        }
                        SequentialAnimation on opacity {
                            running: true; loops: Animation.Infinite
                            NumberAnimation { to: 0; duration: 520; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1; duration: 520; easing.type: Easing.InOutSine }
                        }
                    }
                }

                DragHandler {
                    target: null
                    xAxis.minimum: -200; xAxis.maximum: 0
                    onActiveChanged: { if (!active && xAxis.activeValue < -40) handleBtn("⌫") }
                }
            }

            // Result pop animation
            SequentialAnimation {
                id: numPopAnim
                // Softer spring: less initial squish, gentler overshoot so
                // rapid = presses don't feel mushy. Total: ~230ms vs old 335ms.
                NumberAnimation { target: numScale; properties: "xScale,yScale"; to: 0.94; duration: 35 }
                NumberAnimation { target: numScale; properties: "xScale,yScale"; to: 1.05; duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
                NumberAnimation { target: numScale; properties: "xScale,yScale"; to: 1.00; duration: 80;  easing.type: Easing.InOutQuad }
            }

            // ── → Var assignment row (slides in after = press) ────────
            Rectangle {
                visible: showAssign
                Layout.fillWidth: true
                height: visible ? 42 : 0
                clip: true; radius: 12
                color: Qt.rgba(0.49,0.23,0.93,0.06)
                border.color: Qt.rgba(0.49,0.23,0.93,0.20); border.width: 1
                Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10; spacing: 6
                    Text { text: "→ var:"; font.pixelSize: Math.round(10 * Theme.scale); font.family: Theme.fontSans; color: Theme.accent2; font.weight: Font.Medium }
                    // Letter quick-picks
                    Repeater {
                        model: ["a","b","c","d","e","m","n","x","y","z"]
                        delegate: Rectangle {
                            width: 28; height: 28; radius: 8
                            color: Theme.accentDim; border.color: Qt.rgba(0.67,0.55,1.0,0.35); border.width: 1
                            scale: letMa.pressed ? 0.85 : 1.0
                            Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutBack } }
                            Text { anchors.centerIn: parent; text: modelData; font.pixelSize: Math.round(12 * Theme.scale); font.family: Theme.fontMono; color: Theme.accent2 }
                            MouseArea { id: letMa; anchors.fill: parent; onClicked: assignToVar(modelData) }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    // Close
                    Text { text: "✕"; font.pixelSize: Math.round(12 * Theme.scale); color: Theme.text3; MouseArea { anchors.fill: parent; onClicked: showAssign = false } }
                }
            }

            // ── Paper tape history ────────────────────────────────────
            Rectangle {
                visible: showHist
                Layout.fillWidth: true
                height: visible ? Math.min(tapeListView.contentHeight + 64, 210) : 0
                radius: 16
                clip: true
                Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutQuart } }

                // Receipt paper texture
                color: Theme.dark ? "#0a0816" : "#f9f7f2"
                Behavior on color { ColorAnimation { duration: Theme.normal } }

                // Perforated top edge line
                Rectangle {
                    anchors.top: parent.top; width: parent.width; height: 1
                    color: Theme.dark ? Qt.rgba(0.49,0.23,0.93,0.35) : Qt.rgba(0,0,0,0.08)
                }
                // Dotted receipt perforation decoration
                Row {
                    anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: 6; spacing: 6
                    Repeater {
                        model: 22
                        delegate: Rectangle { width: 4; height: 4; radius: 2; color: Theme.dark ? Qt.rgba(1,1,1,0.06) : Qt.rgba(0,0,0,0.06) }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 12; anchors.topMargin: 16; spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "TAPE"; font.pixelSize: Math.round(8 * Theme.scale); color: Theme.text3; font.letterSpacing: 2.0; font.family: Theme.fontMono; Behavior on color { ColorAnimation { duration: Theme.normal } } }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "clear"; font.pixelSize: Math.round(8 * Theme.scale); color: Theme.text3; font.family: Theme.fontSans
                            MouseArea { anchors.fill: parent; onClicked: { window.calcHistory = []; showHist = false } }
                        }
                    }

                    ListView {
                        id: tapeListView
                        Layout.fillWidth: true; Layout.fillHeight: true
                        model: window ? window.calcHistory : []
                        clip: true; spacing: 0

                        delegate: Item {
                            width: tapeListView.width; height: 40

                            // Tape entry line
                            Rectangle {
                                anchors.bottom: parent.bottom; width: parent.width; height: 1
                                color: Theme.dark ? Qt.rgba(1,1,1,0.05) : Qt.rgba(0,0,0,0.05)
                            }

                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6
                                // Time stamp on far left (like a receipt)
                                Text { text: modelData.time; font.pixelSize: Math.round(8 * Theme.scale); font.family: Theme.fontMono; color: Theme.text3; Layout.preferredWidth: 32 }
                                // Expression
                                Text { text: modelData.expr; color: Theme.text2; font.pixelSize: Math.round(11 * Theme.scale); font.family: Theme.fontMono; Layout.fillWidth: true; elide: Text.ElideRight; Behavior on color { ColorAnimation { duration: Theme.normal } } }
                                // Equals sign
                                Text { text: "="; font.pixelSize: Math.round(11 * Theme.scale); font.family: Theme.fontMono; color: Theme.text3 }
                                // Result — bold, accented
                                Text {
                                    text: modelData.result
                                    color: modelData.result === "Error" ? Theme.red : Theme.accent2
                                    font.pixelSize: Math.round(14 * Theme.scale); font.family: Theme.fontMono; font.weight: Font.Medium
                                    Behavior on color { ColorAnimation { duration: Theme.normal } }
                                }
                                // Reuse button
                                Rectangle {
                                    width: 24; height: 24; radius: 7
                                    color: reuseHover ? Theme.accentDim : "transparent"
                                    border.color: reuseHover ? Qt.rgba(0.67,0.55,1.0,0.40) : "transparent"; border.width: 1
                                    property bool reuseHover: false
                                    Behavior on color { ColorAnimation { duration: 80 } }
                                    Text { anchors.centerIn: parent; text: "↩"; font.pixelSize: Math.round(11 * Theme.scale); color: Theme.accent2 }
                                    MouseArea {
                                        anchors.fill: parent; hoverEnabled: true
                                        onEntered: parent.reuseHover = true
                                        onExited:  parent.reuseHover = false
                                        onClicked: {
                                            if (modelData.result === "Error") return
                                            expr = modelData.result; justEval = true; showHist = false
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

        }   // end topCol ColumnLayout
    }   // end topFlick Flickable

        // ── SCI strip toggle row (outside scroll area) ────────────────
        RowLayout {
            Layout.fillWidth: true; spacing: 8

            Rectangle {
                height: 20; width: sciToggleLbl.implicitWidth + 18; radius: 10
                color: sciOpen ? Theme.accentDim : Theme.actionBg
                border.color: sciOpen ? Theme.accent : Theme.actionBdr; border.width: 1
                Behavior on color { ColorAnimation { duration: 160 } }
                Text { id: sciToggleLbl; anchors.centerIn: parent; text: sciOpen ? "SCI ▲" : "SCI ▼"; font.pixelSize: Math.round(9 * Theme.scale); font.weight: Font.Bold; font.family: Theme.fontSans; font.letterSpacing: 1.2; color: sciOpen ? Theme.accent2 : Theme.text3; Behavior on color { ColorAnimation { duration: 160 } } }
                TapHandler { onTapped: sciOpen = !sciOpen }
            }

            Rectangle {
                height: 20; width: 46; radius: 10
                color: Qt.rgba(0.02, 0.71, 0.83, angleMode === "deg" ? (Theme.dark ? 0.12 : 0.09) : 0.04)
                border.color: Qt.rgba(0.02, 0.71, 0.83, angleMode === "deg" ? 0.38 : 0.12); border.width: 1
                Text { anchors.centerIn: parent; text: angleMode.toUpperCase(); font.pixelSize: Math.round(9 * Theme.scale); font.family: Theme.fontSans; font.weight: Font.Bold; color: angleMode === "deg" ? Theme.cyan : Theme.text3; Behavior on color { ColorAnimation { duration: 120 } } }
                TapHandler { onTapped: angleMode = angleMode === "deg" ? "rad" : "deg" }
                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }

        // ── SCI strip (collapsible, outside scroll area) ──────────────
        Item {
            Layout.fillWidth: true
            height: sciOpen ? 30 : 0; clip: true
            Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Flickable {
                anchors.fill: parent; contentWidth: sciRow.implicitWidth + 4
                flickableDirection: Flickable.HorizontalFlick; clip: true
                Row { id: sciRow; spacing: 6; x: 2
                    Repeater {
                        model: sciStrip
                        delegate: CalcButton {
                            label: modelData; btnType: "sci"
                            implicitHeight: 26
                            width: Math.max(46, label.length * 7 + 18)
                            onClicked: handleBtn(label)
                        }
                    }
                }
            }
        }

        // ── Main button grid — fills all remaining screen space ───────
        // Layout.fillHeight: true on every row/button makes them grow on
        // tall devices and tablet-sized screens automatically.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4

                // Number pad (3 cols × 4 rows) + bottom row (± and .)
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4

                    Repeater {
                        model: numRows
                        delegate: RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 4
                            Repeater {
                                model: modelData
                                delegate: CalcButton {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.minimumHeight: 36
                                    Layout.maximumHeight: 62
                                    label: modelData
                                    btnType: root.btnType(modelData)
                                    onClicked: handleBtn(label)
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 4
                        Repeater {
                            model: ["±", "."]
                            delegate: CalcButton {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumHeight: 32
                                Layout.maximumHeight: 52
                                label: modelData; btnType: "dim"
                                onClicked: handleBtn(label)
                            }
                        }
                    }
                }

                // Operators column (right side)
                ColumnLayout {
                    Layout.preferredWidth: 56
                    Layout.fillHeight: true
                    spacing: 4

                    Repeater {
                        model: opCol
                        delegate: CalcButton {
                            Layout.preferredWidth: 56
                            Layout.fillHeight: true
                            Layout.minimumHeight: 36
                            Layout.maximumHeight: 62
                            label: modelData; btnType: "op"
                            onClicked: handleBtn(label)
                        }
                    }

                    CalcButton {
                        Layout.preferredWidth: 56
                        Layout.fillHeight: true
                        Layout.minimumHeight: 32
                        Layout.maximumHeight: 52
                        label: "%"; btnType: "dim"
                        onClicked: handleBtn("%")
                    }
                }
            }

            // Equals — always a bit taller than standard rows
            CalcButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                Layout.minimumHeight: 40
                Layout.maximumHeight: 64
                label: "="; btnType: "eq"
                onClicked: handleBtn("=")
            }

        }   // end button ColumnLayout

    }   // end outer ColumnLayout

    // ── Keyboard input ────────────────────────────────────────────────
    Keys.onPressed: function(event) {
        switch (event.key) {
            case Qt.Key_Return:
            case Qt.Key_Enter:       handleBtn("=");  event.accepted = true; break
            case Qt.Key_Backspace:   handleBtn("⌫");  event.accepted = true; break
            case Qt.Key_Escape:      handleBtn("C");   event.accepted = true; break
            case Qt.Key_Plus:        handleBtn("+");   event.accepted = true; break
            case Qt.Key_Minus:       handleBtn("−");   event.accepted = true; break
            case Qt.Key_Asterisk:    handleBtn("×");   event.accepted = true; break
            case Qt.Key_Slash:       handleBtn("÷");   event.accepted = true; break
            case Qt.Key_ParenLeft:   handleBtn("(");   event.accepted = true; break
            case Qt.Key_ParenRight:  handleBtn(")");   event.accepted = true; break
            case Qt.Key_AsciiCircum: handleBtn("^");   event.accepted = true; break
            case Qt.Key_Percent:     handleBtn("%");   event.accepted = true; break
            case Qt.Key_Period:      handleBtn(".");    event.accepted = true; break
            default:
                if (event.text >= "0" && event.text <= "9") { handleBtn(event.text); event.accepted = true }
        }
    }
    focus: visible
}
