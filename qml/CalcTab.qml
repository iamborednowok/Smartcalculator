import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import SmartCalc.Backend 1.0
import "components"

Item {
    id: root

    // ── Entrance animation (plays each time this tab becomes current) ──
    // A quick fade + gentle pop-in on switching to this tab instead of
    // just snapping into view — see Theme.popDuration/popEasing.
    opacity: 1.0
    scale: 1.0
    // Driven from Main.qml (root.currentTab === 0), not
    // StackLayout.isCurrentItem — see GraphTab.qml for why (other tabs
    // are now lazy-loaded through a Loader; CalcTab stays a direct
    // StackLayout child since it's the startup tab, but uses the same
    // mechanism as the rest for consistency).
    property bool isCurrentTab: false
    onIsCurrentTabChanged: if (isCurrentTab) { enterFade.restart(); enterScale.restart() }
    NumberAnimation { id: enterFade;  target: root; property: "opacity"; from: 0.0;  to: 1.0; duration: Theme.popDuration; easing.type: Easing.OutQuad }
    NumberAnimation { id: enterScale; target: root; property: "scale";   from: 0.97; to: 1.0; duration: Theme.popDuration; easing.type: Theme.popEasing; easing.overshoot: Theme.popOvershoot }

    // NOTE: mathEngine / settings / apiClient are intentionally NOT declared
    // here. They're single shared instances declared once at Main.qml's root
    // (per AppSettings.h's own doc comment: "Instantiate once in Main.qml")
    // and reached via QML's normal id scope-chain, since every tab is
    // instantiated as a direct child of Main.qml. Declaring a second local
    // instance per tab would silently fork state (e.g. two AppSettings
    // objects each persisting independently) — easy bug to reintroduce
    // when adding a new tab, so don't.
    property var window: ApplicationWindow.window

    // ── State ────────────────────────────────────────────────────────
    property string expr:       ""
    property string prevExpr:   ""
    property bool   justEval:   false
    property string angleMode:  "deg"
    property bool   fracMode:   settings.fracMode
    property bool   sciOpen:    settings.sciMode
    property bool   showHist:   false
    property bool   showAssign: false
    property var    variables:  ({})

    onFracModeChanged: settings.fracMode = fracMode
    onSciOpenChanged:  settings.sciMode  = sciOpen

    // ── Easter egg: upside-down calculator words ─────────────────────
    // The classic LED-calculator gag, older than this app by decades:
    // flip the display 180° and certain numbers read as words. Two things
    // happen in a 180° flip, not one — each digit's glyph maps to a
    // (possibly different) letter, AND the digit order reverses, since
    // left/right flips along with up/down. So the number that spells a
    // word is the word's letters, reversed, each mapped back to its
    // digit — not just "the word's letters as digits" in reading order.
    //
    // Digit->letter map used here: 0=O 1=I 3=E 4=h 5=S 7=L 8=B. Deliberately
    // NOT using 2, 6, or 9 — those map to Z/g/G, which is a genuinely
    // ambiguous, font-dependent part of this gag (6 and 9 both plausibly
    // read as g/G depending on the display), and getting one of those
    // wrong would mean shipping a "word" that does not actually read
    // right. Every entry below only uses the seven unambiguous digits, so
    // all of them are exact, not approximate.
    readonly property var flipWords: ({
        "0.7734": "hELLO",
        "707":    "LOL",
        "5508":   "BOSS",
        "77345":  "ShELL",
        "505":    "SOS"
    })
    // Direct references — no flipping, the number just means something on
    // its own. Kept as a separate table from flipWords since the reveal
    // text explains a fact rather than "here's the word", and because
    // mixing the two mechanics into one lookup would make a future reader
    // have to guess which kind any given entry is.
    readonly property var funNumbers: ({
        "42": "The Answer to Life, the Universe, and Everything."
    })
    property string flipRevealWord: ""
    onExprChanged: {
        var word = flipWords[expr]
        if (word) {
            flipRevealWord = word
            if (window) window.showToast(word + " 🙃 (flip it)", true)
            return
        }
        var fact = funNumbers[expr]
        if (fact && window) window.showToast(fact, true)
    }

    readonly property string displayVal: expr === "" ? "0" : expr
    readonly property int    btnH: Math.round(60 * Theme.scale)

    readonly property var sciStrip: [
        "sin(", "cos(", "tan(", "log(", "ln(", "√(", "(", ")",
        "x²", "xʸ", "π", "e", "n!", "nCr(", "nPr(", "sinh("
    ]

    // Hoisted out of handleBtn() below — these were previously two array
    // literals rebuilt (and their .indexOf run) on every single keypress.
    readonly property var operatorKeys:      ["+", "−", "×", "÷", "^"]
    readonly property var exprBoundaryKeys:  ["+", "−", "×", "÷", "^", "("]

    // ── Formatting helpers ──────────────────────────────────────────────
    function displayFmt(v) {
        if (v === "Error" || v === "0" || v.indexOf("/") >= 0) return v
        var num = parseFloat(v)
        if (!isFinite(num)) return v
        var parts = v.split(".")
        parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",")
        return parts.join(".")
    }

    function displayFontSize(v) {
        var base
        if (v.length > 18) base = 22
        else if (v.length > 13) base = 30
        else if (v.length > 9)  base = 40
        else base = 52
        return Math.round(base * Theme.scale)
    }

    // ── Variables ───────────────────────────────────────────────────────
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
        variables = variables   // trigger binding refresh
        showAssign = false
        if (window) window.showToast(letter + " = " + expr, true)
    }

    // ── Input handling ────────────────────────────────────────────────
    function handleBtn(val) {
        if (val === "C") { expr = ""; prevExpr = ""; justEval = false; showAssign = false; return }
        if (val === "⌫") {
            if (justEval) { expr = ""; justEval = false; return }
            expr = expr.length > 1 ? expr.slice(0, -1) : ""
            return
        }
        if (val === "±") { expr = expr.startsWith("-") ? expr.slice(1) : (expr ? "-" + expr : ""); justEval = false; return }
        if (val === "%") {
            var pct = parseFloat(expr)
            if (!isNaN(pct)) { expr = mathEngine.formatNumber(pct / 100); justEval = false }
            return
        }
        if (val === "x²") { if (expr) expr = "(" + expr + ")^2"; justEval = false; return }
        if (val === "xʸ") { if (expr) expr += "^"; justEval = false; return }
        if (val === "n!") { if (expr) expr = "fact(" + expr + ")"; justEval = false; return }

        if (val === "=") {
            var t = substituteVars(expr || "0")
            var r = mathEngine.evaluate(t, angleMode === "deg", fracMode)
            prevExpr = expr + " ="; expr = r; justEval = true; showAssign = (r !== "Error")
            if (window) window.addHistory(t, r)
            return
        }

        var isOp = operatorKeys.indexOf(val) >= 0
        if (justEval) { expr = isOp ? expr + val : val; justEval = false; showAssign = false; return }
        if (val === "." && /\.\d*$/.test(expr)) return
        if (val === ".") {
            var lastCh = expr.length > 0 ? expr[expr.length - 1] : ""
            if (expr === "" || exprBoundaryKeys.indexOf(lastCh) >= 0) expr += "0"
        }
        expr += val
        showAssign = false
    }

    // ── Clipboard ───────────────────────────────────────────────────────
    TextEdit { id: clipHelper; visible: false; text: "" }
    function copyResult() {
        if (!justEval || expr === "Error") return
        clipHelper.text = expr
        clipHelper.selectAll()
        clipHelper.copy()
        if (window) window.showToast("Copied", true)
    }

    // ── Layout ────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.sp4
        spacing: Theme.sp3

        // ── History (collapsible) ─────────────────────────────────────
        Item {
            Layout.fillWidth: true
            visible: root.showHist
            height: visible ? histCol.implicitHeight : 0
            clip: true
            Behavior on height { NumberAnimation { duration: Theme.normal } }

            Column {
                id: histCol
                width: parent.width
                spacing: Theme.sp2

                Text {
                    visible: !window || window.calcHistory.length === 0
                    text: "No history yet"
                    color: Theme.textFaint
                    font.family: Theme.fontSans
                    font.pixelSize: Math.round(13 * Theme.scale)
                }

                Repeater {
                    model: window ? window.calcHistory : []
                    delegate: Item {
                        width: histCol.width
                        height: Math.round(32 * Theme.scale)

                        RowLayout {
                            anchors.fill: parent
                            spacing: Theme.sp2
                            Text {
                                Layout.fillWidth: true
                                text: modelData.expr
                                elide: Text.ElideLeft
                                color: Theme.textDim
                                font.family: Theme.fontMono
                                font.pixelSize: Math.round(13 * Theme.scale)
                            }
                            Text {
                                text: modelData.result
                                color: Theme.text
                                font.family: Theme.fontMono
                                font.weight: Font.Medium
                                font.pixelSize: Math.round(13 * Theme.scale)
                            }
                        }
                        TapHandler {
                            onTapped: {
                                if (modelData.result !== "Error") {
                                    expr = modelData.result; justEval = true; showHist = false
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Display ─────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Theme.sp5
            spacing: Theme.sp1

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                text: root.prevExpr
                visible: root.prevExpr.length > 0
                elide: Text.ElideLeft
                font.family: Theme.fontMono
                font.pixelSize: Math.round(16 * Theme.scale)
                color: Theme.textDim
            }

            Item {
                Layout.fillWidth: true
                height: resultText.implicitHeight

                // Neon glow bloom behind the result in dark mode
                Rectangle {
                    visible: Theme.dark && root.justEval && root.expr !== "Error"
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width:  Math.min(resultText.implicitWidth + Math.round(40 * Theme.scale), parent.width)
                    height: resultText.implicitHeight + Math.round(20 * Theme.scale)
                    radius: Math.round(20 * Theme.scale)
                    color:  Theme.glowB2
                    Behavior on width { NumberAnimation { duration: Theme.normal } }
                }

                Text {
                    id: resultText
                    anchors.right: parent.right
                    anchors.left:  parent.left
                    horizontalAlignment: Text.AlignRight
                    text: root.displayFmt(root.displayVal)
                    elide: Text.ElideLeft
                    font.family: Theme.fontMono
                    font.weight: Font.Medium
                    font.pixelSize: root.displayFontSize(root.displayVal)
                    color: root.expr === "Error" ? Theme.accent : Theme.text
                    TapHandler { onTapped: root.copyResult() }
                }
            }
        }

        // ── Assign-to-variable strip ──────────────────────────────────
        Flickable {
            Layout.fillWidth: true
            height: root.showAssign ? Math.round(40 * Theme.scale) : 0
            visible: height > 0
            clip: true
            contentWidth: assignRow.implicitWidth
            flickableDirection: Flickable.HorizontalFlick
            Behavior on height { NumberAnimation { duration: Theme.normal } }

            Row {
                id: assignRow
                spacing: Theme.sp2
                height: parent.height

                Text {
                    text: "store →"
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.textFaint
                    font.family: Theme.fontSans
                    font.pixelSize: Math.round(12 * Theme.scale)
                }
                Repeater {
                    model: ["A", "B", "C", "D", "E", "F"]
                    delegate: Rectangle {
                        width: Math.round(34 * Theme.scale)
                        height: Math.round(34 * Theme.scale)
                        radius: Theme.rSm
                        color: Theme.surfaceOp
                        // Subtle rim (both modes — see Theme.edgeB2)
                        Rectangle {
                            anchors.fill: parent; anchors.margins: -1
                            radius: parent.radius + 1
                            color: "transparent"
                            border.width: 1; border.color: Theme.edgeB2
                        }
                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: Theme.accent2
                            font.family: Theme.fontMono
                            font.weight: Font.Medium
                            font.pixelSize: Math.round(14 * Theme.scale)
                        }
                        TapHandler { onTapped: root.assignToVar(modelData) }
                    }
                }
            }
        }

        // ── Toggle row ─────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp4

            Text {
                text: root.angleMode.toUpperCase()
                color: Theme.accent2
                font.family: Theme.fontSans
                font.weight: Font.Bold
                font.pixelSize: Math.round(12 * Theme.scale)
                TapHandler { onTapped: root.angleMode = root.angleMode === "deg" ? "rad" : "deg" }
            }
            Text {
                text: "FRAC"
                color: root.fracMode ? Theme.accent2 : Theme.textFaint
                font.family: Theme.fontSans
                font.weight: Font.Bold
                font.pixelSize: Math.round(12 * Theme.scale)
                TapHandler { onTapped: root.fracMode = !root.fracMode }
            }

            Item { Layout.fillWidth: true }

            Text {
                text: root.sciOpen ? "SCI ⌃" : "SCI ⌄"
                color: root.sciOpen ? Theme.accent : Theme.textFaint
                font.family: Theme.fontSans
                font.weight: Font.Bold
                font.pixelSize: Math.round(12 * Theme.scale)
                TapHandler { onTapped: root.sciOpen = !root.sciOpen }
            }
            Text {
                text: "HISTORY"
                color: root.showHist ? Theme.accent : Theme.textFaint
                font.family: Theme.fontSans
                font.weight: Font.Bold
                font.pixelSize: Math.round(12 * Theme.scale)
                TapHandler { onTapped: root.showHist = !root.showHist }
            }
        }

        // ── Scientific strip (collapsible) ────────────────────────────
        Flickable {
            Layout.fillWidth: true
            height: root.sciOpen ? Math.round(40 * Theme.scale) : 0
            visible: height > 0
            clip: true
            contentWidth: sciRow.implicitWidth
            flickableDirection: Flickable.HorizontalFlick
            Behavior on height { NumberAnimation { duration: Theme.normal } }

            Row {
                id: sciRow
                spacing: Theme.sp4
                height: parent.height

                Repeater {
                    model: root.sciStrip
                    delegate: Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData
                        color: Theme.accent2
                        font.family: Theme.fontMono
                        font.pixelSize: Math.round(15 * Theme.scale)
                        TapHandler { onTapped: root.handleBtn(modelData) }
                    }
                }
            }
        }

        // ── Spacer — keeps the grid from stretching edge-to-edge ───────
        Item { Layout.fillHeight: true; Layout.minimumHeight: Theme.sp3 }

        // ── Button grid (4 × 5) ─────────────────────────────────────
        GridLayout {
            Layout.fillWidth: true
            columns: 4
            rowSpacing: Theme.sp2
            columnSpacing: Theme.sp2

            CalcButton { Layout.fillWidth: true; Layout.preferredHeight: root.btnH; label: "7"; btnType: "digit"; onClicked: root.handleBtn("7") }
            CalcButton { Layout.fillWidth: true; Layout.preferredHeight: root.btnH; label: "8"; btnType: "digit"; onClicked: root.handleBtn("8") }
            CalcButton { Layout.fillWidth: true; Layout.preferredHeight: root.btnH; label: "9"; btnType: "digit"; onClicked: root.handleBtn("9") }
            CalcButton { Layout.fillWidth: true; Layout.preferredHeight: root.btnH; label: "÷"; btnType: "op";    onClicked: root.handleBtn("÷") }

            CalcButton { Layout.fillWidth: true; Layout.preferredHeight: root.btnH; label: "4"; btnType: "digit"; onClicked: root.handleBtn("4") }
            CalcButton { Layout.fillWidth: true; Layout.preferredHeight: root.btnH; label: "5"; btnType: "digit"; onClicked: root.handleBtn("5") }
            CalcButton { Layout.fillWidth: true; Layout.preferredHeight: root.btnH; label: "6"; btnType: "digit"; onClicked: root.handleBtn("6") }
            CalcButton { Layout.fillWidth: true; Layout.preferredHeight: root.btnH; label: "×"; btnType: "op";    onClicked: root.handleBtn("×") }

            CalcButton { Layout.fillWidth: true; Layout.preferredHeight: root.btnH; label: "1"; btnType: "digit"; onClicked: root.handleBtn("1") }
            CalcButton { Layout.fillWidth: true; Layout.preferredHeight: root.btnH; label: "2"; btnType: "digit"; onClicked: root.handleBtn("2") }
            CalcButton { Layout.fillWidth: true; Layout.preferredHeight: root.btnH; label: "3"; btnType: "digit"; onClicked: root.handleBtn("3") }
            CalcButton { Layout.fillWidth: true; Layout.preferredHeight: root.btnH; label: "−"; btnType: "op";    onClicked: root.handleBtn("−") }

            CalcButton { Layout.fillWidth: true; Layout.preferredHeight: root.btnH; label: "%"; btnType: "func";  onClicked: root.handleBtn("%") }
            CalcButton { Layout.fillWidth: true; Layout.preferredHeight: root.btnH; label: "0"; btnType: "digit"; onClicked: root.handleBtn("0") }
            CalcButton { Layout.fillWidth: true; Layout.preferredHeight: root.btnH; label: "."; btnType: "digit"; onClicked: root.handleBtn(".") }
            CalcButton { Layout.fillWidth: true; Layout.preferredHeight: root.btnH; label: "+"; btnType: "op";    onClicked: root.handleBtn("+") }

            CalcButton { Layout.fillWidth: true; Layout.preferredHeight: root.btnH; label: "C"; btnType: "clear"; onClicked: root.handleBtn("C") }
            CalcButton { Layout.fillWidth: true; Layout.preferredHeight: root.btnH; label: "±"; btnType: "func";  onClicked: root.handleBtn("±") }
            CalcButton { Layout.fillWidth: true; Layout.preferredHeight: root.btnH; label: "⌫"; btnType: "clear"; onClicked: root.handleBtn("⌫") }
            CalcButton { Layout.fillWidth: true; Layout.preferredHeight: root.btnH; label: "="; btnType: "eq";    onClicked: root.handleBtn("=") }
        }
    }

    // ── Keyboard ────────────────────────────────────────────────────────
    Keys.onPressed: function(event) {
        switch (event.key) {
            case Qt.Key_Return:
            case Qt.Key_Enter:       handleBtn("=");  event.accepted = true; break
            case Qt.Key_Backspace:   handleBtn("⌫");  event.accepted = true; break
            case Qt.Key_Escape:      handleBtn("C");  event.accepted = true; break
            case Qt.Key_Plus:        handleBtn("+");  event.accepted = true; break
            case Qt.Key_Minus:       handleBtn("−");  event.accepted = true; break
            case Qt.Key_Asterisk:    handleBtn("×");  event.accepted = true; break
            case Qt.Key_Slash:       handleBtn("÷");  event.accepted = true; break
            case Qt.Key_ParenLeft:   handleBtn("(");  event.accepted = true; break
            case Qt.Key_ParenRight:  handleBtn(")");  event.accepted = true; break
            case Qt.Key_AsciiCircum: handleBtn("^");  event.accepted = true; break
            case Qt.Key_Percent:     handleBtn("%");  event.accepted = true; break
            case Qt.Key_Period:      handleBtn(".");  event.accepted = true; break
            default:
                if (event.text >= "0" && event.text <= "9") { handleBtn(event.text); event.accepted = true }
        }
    }
    focus: visible
}
