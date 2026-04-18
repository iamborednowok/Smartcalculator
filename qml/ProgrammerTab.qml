import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "components"

Item {
    id: root

    // ── State ─────────────────────────────────────────────────────────
    property int  bitWidth:    32          // 8 | 16 | 32 | 64
    property int  inputBase:   10          // 10 | 16 | 2 | 8
    property string rawInput:  ""         // current typed string
    property bool   justEval:  false

    // Clamped integer value — JS integers are safe up to 2^53
    property double currentVal: {
        if (rawInput === "" || rawInput === "-") return 0
        var n = inputBase === 16 ? parseInt(rawInput, 16)
              : inputBase === 2  ? parseInt(rawInput, 2)
              : inputBase === 8  ? parseInt(rawInput, 8)
              : parseFloat(rawInput)
        return isNaN(n) ? 0 : clamp(Math.trunc(n))
    }

    function clamp(n) {
        var max = Math.pow(2, bitWidth) - 1
        return ((n % Math.pow(2, bitWidth)) + Math.pow(2, bitWidth)) % Math.pow(2, bitWidth)
    }

    function bitAt(pos) {
        // pos 0 = LSB.
        // IMPORTANT: do NOT use (val >> pos) & 1 or (val / p) & 1 — JS
        // bitwise operators coerce to signed Int32, corrupting bits >= 31.
        // Float-division + floor + modulo stays in IEEE-754 space.
        return Math.floor(currentVal / Math.pow(2, pos)) % 2 !== 0 ? 1 : 0
    }

    function toggleBit(pos) {
        // Avoid XOR (^) — it coerces to Int32. Use arithmetic instead.
        var p = Math.pow(2, pos)
        var toggled = bitAt(pos) === 1 ? currentVal - p : currentVal + p
        currentVal = clamp(toggled)
        rawInput = currentVal.toString(inputBase).toUpperCase()
        justEval = false
    }

    // ── Formatted display strings ─────────────────────────────────────
    function fmtDec(v) { return v.toString(10) }
    function fmtHex(v) {
        var h = clamp(v).toString(16).toUpperCase()
        var pad = Math.ceil(bitWidth / 4)
        while (h.length < pad) h = "0" + h
        // insert spaces every 4 chars
        return h.match(/.{1,4}/g).join(" ")
    }
    function fmtBin(v) {
        var b = clamp(v).toString(2)
        while (b.length < bitWidth) b = "0" + b
        return b.match(/.{1,8}/g).join("  ")
    }
    function fmtOct(v) { return clamp(v).toString(8) }

    // ── Input handling ────────────────────────────────────────────────
    function appendChar(c) {
        if (justEval) { rawInput = ""; justEval = false }

        // Validate char for current base
        if (inputBase === 2  && !/^[01]$/.test(c))    return
        if (inputBase === 8  && !/^[0-7]$/.test(c))   return
        if (inputBase === 10 && !/^[0-9]$/.test(c))   return
        if (inputBase === 16 && !/^[0-9A-F]$/.test(c)) return

        rawInput += c
    }

    function doBitwiseOp(op) {
        // Store left operand + op, wait for second operand
        pendingOp = op
        pendingVal = currentVal
        rawInput = ""
        justEval = false
    }

    function doEquals() {
        if (pendingOp === "") {
            justEval = true; return
        }
        var a = pendingVal, b = currentVal
        var result = 0
        // Bitwise AND/OR/XOR coerce to Int32 in JS, so they only work
        // correctly for 8/16-bit widths. For 32-bit we mask to keep the
        // result positive, and for 64-bit we fall back to arithmetic.
        switch (pendingOp) {
            case "AND": result = bitWidth <= 32 ? ((a & b) >>> 0) : bitwiseAnd64(a, b); break
            case "OR":  result = bitWidth <= 32 ? ((a | b) >>> 0) : bitwiseOr64(a, b);  break
            case "XOR": result = bitWidth <= 32 ? ((a ^ b) >>> 0) : bitwiseXor64(a, b); break
            case "+":   result = a + b;   break
            case "-":   result = a - b;   break
            case "*":   result = a * b;   break
            case "/":   result = b !== 0 ? Math.trunc(a / b) : 0; break
            case "<<":  result = a * Math.pow(2, b); break
            case ">>":  result = Math.trunc(a / Math.pow(2, b)); break
        }
        currentVal = clamp(result)
        rawInput = currentVal.toString(inputBase).toUpperCase()
        pendingOp = ""; pendingVal = 0
        justEval = true
        resultFlash.restart()
    }

    // 64-bit-safe bitwise helpers using 32-bit hi/lo decomposition
    function bitwiseAnd64(a, b) {
        var aHi = Math.floor(a / 4294967296), aLo = a % 4294967296
        var bHi = Math.floor(b / 4294967296), bLo = b % 4294967296
        return ((aHi & bHi) >>> 0) * 4294967296 + ((aLo & bLo) >>> 0)
    }
    function bitwiseOr64(a, b) {
        var aHi = Math.floor(a / 4294967296), aLo = a % 4294967296
        var bHi = Math.floor(b / 4294967296), bLo = b % 4294967296
        return ((aHi | bHi) >>> 0) * 4294967296 + ((aLo | bLo) >>> 0)
    }
    function bitwiseXor64(a, b) {
        var aHi = Math.floor(a / 4294967296), aLo = a % 4294967296
        var bHi = Math.floor(b / 4294967296), bLo = b % 4294967296
        return ((aHi ^ bHi) >>> 0) * 4294967296 + ((aLo ^ bLo) >>> 0)
    }

    property string pendingOp:  ""
    property double pendingVal: 0

    function doNOT() {
        var maxVal = Math.pow(2, bitWidth) - 1
        currentVal = clamp(maxVal - currentVal)
        rawInput = currentVal.toString(inputBase).toUpperCase()
    }

    function doClear() { rawInput = ""; pendingOp = ""; pendingVal = 0; justEval = false }
    function doDelete() {
        if (rawInput.length > 0) rawInput = rawInput.slice(0, -1)
    }

    function switchBase(base) {
        var v = currentVal
        inputBase = base
        rawInput = v === 0 ? "" : v.toString(base).toUpperCase()
    }

    // ── Keyboard rows ─────────────────────────────────────────────────
    readonly property var kbdRows: [
        ["A","B","C","D","E","F", "AND", "OR" ],
        ["7","8","9","<<",">>","NOT","CLR","DEL"],
        ["4","5","6","XOR"," +"," -", " *", " /"],
        ["1","2","3","0"," ","=","",""]
    ]

    // ── UI ────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        // ── Header ───────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Text {
                text: "PROGRAMMER"
                font.pixelSize: 15; font.weight: Font.Bold
                font.family: Theme.fontSans; font.letterSpacing: 1.5
                color: Theme.accent2
            }
            Item { Layout.fillWidth: true }
            // Bit width selector
            Repeater {
                model: [8, 16, 32, 64]
                delegate: Rectangle {
                    height: 24; width: 36; radius: 8
                    color: bitWidth === modelData ? Theme.accentDim : "transparent"
                    border.color: bitWidth === modelData ? Theme.accent : Theme.border1; border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                        anchors.centerIn: parent
                        text: modelData + ""
                        font.pixelSize: 9; font.weight: Font.Bold; font.family: Theme.fontSans
                        color: bitWidth === modelData ? Theme.accent2 : Theme.text3
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    MouseArea { anchors.fill: parent; onClicked: { bitWidth = modelData; rawInput = clamp(currentVal).toString(inputBase).toUpperCase() } }
                }
            }
        }

        // ── Base selector ────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true; spacing: 6
            Repeater {
                model: [{ label: "DEC", base: 10 }, { label: "HEX", base: 16 },
                        { label: "BIN", base: 2  }, { label: "OCT", base: 8  }]
                delegate: Rectangle {
                    Layout.fillWidth: true; height: 28; radius: 10
                    color: inputBase === modelData.base ? Qt.rgba(0.02,0.71,0.83,0.15) : "transparent"
                    border.color: inputBase === modelData.base ? Theme.cyan : Theme.border1; border.width: 1
                    Behavior on color { ColorAnimation { duration: 130 } }
                    Text {
                        anchors.centerIn: parent; text: modelData.label
                        font.pixelSize: 9; font.weight: Font.Bold; font.family: Theme.fontSans
                        color: inputBase === modelData.base ? Theme.cyan : Theme.text3
                        Behavior on color { ColorAnimation { duration: 130 } }
                    }
                    MouseArea { anchors.fill: parent; onClicked: switchBase(modelData.base) }
                }
            }
        }

        // ── Value display card ───────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: displayCol.implicitHeight + 18
            radius: 16
            color: Theme.glass1
            border.color: Theme.border1; border.width: 1

            // Top sheen
            Rectangle {
                anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.6; height: 1; y: 1; radius: 1
                color: Qt.rgba(1,1,1, Theme.dark ? 0.12 : 0.85)
            }

            SequentialAnimation {
                id: resultFlash; running: false
                NumberAnimation { target: displayCard; property: "opacity"; to: 0.4; duration: 60 }
                NumberAnimation { target: displayCard; property: "opacity"; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
            }
            id: displayCard

            ColumnLayout {
                id: displayCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                spacing: 4

                // DEC row
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "DEC"; font.pixelSize: 9; color: Theme.text3; font.family: Theme.fontMono; minimumPixelSize: 8; Layout.preferredWidth: 28 }
                    Text {
                        Layout.fillWidth: true; horizontalAlignment: Text.AlignRight
                        text: fmtDec(currentVal)
                        font.pixelSize: inputBase === 10 ? 22 : 14
                        font.family: Theme.fontMono
                        color: inputBase === 10 ? Theme.text : Theme.text2
                        Behavior on font.pixelSize { NumberAnimation { duration: 100 } }
                        elide: Text.ElideLeft
                    }
                }
                // HEX row
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "HEX"; font.pixelSize: 9; color: Theme.text3; font.family: Theme.fontMono; Layout.preferredWidth: 28 }
                    Text {
                        Layout.fillWidth: true; horizontalAlignment: Text.AlignRight
                        text: "0x " + fmtHex(currentVal)
                        font.pixelSize: inputBase === 16 ? 18 : 12
                        font.family: Theme.fontMono
                        color: inputBase === 16 ? Theme.cyan : Theme.text2
                        Behavior on font.pixelSize { NumberAnimation { duration: 100 } }
                        elide: Text.ElideLeft
                    }
                }
                // OCT row
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "OCT"; font.pixelSize: 9; color: Theme.text3; font.family: Theme.fontMono; Layout.preferredWidth: 28 }
                    Text {
                        Layout.fillWidth: true; horizontalAlignment: Text.AlignRight
                        text: "0o " + fmtOct(currentVal)
                        font.pixelSize: inputBase === 8 ? 16 : 11
                        font.family: Theme.fontMono
                        color: inputBase === 8 ? Qt.rgba(0.95,0.62,0.07,1) : Theme.text2
                        Behavior on font.pixelSize { NumberAnimation { duration: 100 } }
                    }
                }
                // BIN row (only first 16 bits to fit)
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "BIN"; font.pixelSize: 9; color: Theme.text3; font.family: Theme.fontMono; Layout.preferredWidth: 28 }
                    Text {
                        Layout.fillWidth: true; horizontalAlignment: Text.AlignRight
                        text: fmtBin(currentVal)
                        font.pixelSize: inputBase === 2 ? 11 : 9
                        font.family: Theme.fontMono
                        color: inputBase === 2 ? Theme.accent2 : Theme.text3
                        elide: Text.ElideLeft
                    }
                }
                // Pending op indicator
                Text {
                    visible: pendingOp !== ""
                    text: "← " + pendingVal.toString(inputBase).toUpperCase() + "  " + pendingOp + "  ?"
                    font.pixelSize: 9; font.family: Theme.fontMono
                    color: Qt.rgba(0.95,0.62,0.07,0.85)
                }
            }
        }

        // ── Bit Toggler ──────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: bitGrid.implicitHeight + 14
            radius: 14
            color: Theme.glass1
            border.color: Theme.border1; border.width: 1
            clip: true

            // Top sheen
            Rectangle {
                anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.5; height: 1; y: 1; radius: 1
                color: Qt.rgba(1,1,1, Theme.dark ? 0.10 : 0.80)
            }

            Column {
                id: bitGrid
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                spacing: 4

                Repeater {
                    // rows: 1 row per byte, starting from MSB row
                    model: bitWidth / 8
                    delegate: Row {
                        spacing: 3
                        anchors.horizontalCenter: parent.horizontalCenter
                        readonly property int byteIndex: (bitWidth / 8) - 1 - index  // MSB byte first

                        // Byte label
                        Text {
                            text: "B" + byteIndex
                            width: 18; font.pixelSize: 7; font.family: Theme.fontMono
                            color: Theme.text3; verticalAlignment: Text.AlignVCenter
                            height: 18
                        }

                        // 8 bits, MSB first within byte
                        Repeater {
                            model: 8
                            delegate: Rectangle {
                                readonly property int bitPos: byteIndex * 8 + (7 - index)
                                readonly property int bitVal: bitAt(bitPos)
                                width: Math.max(10, (root.width - 110) / 8 - 3)
                                height: 18; radius: 4
                                color: bitVal === 1
                                    ? (bitPos >= bitWidth - 8 ? Qt.rgba(0.96,0.25,0.37,0.30)
                                                              : Qt.rgba(0.49,0.23,0.93,0.35))
                                    : Qt.rgba(1,1,1,0.04)
                                border.color: bitVal === 1
                                    ? (bitPos >= bitWidth - 8 ? Qt.rgba(0.96,0.25,0.37,0.60)
                                                              : Qt.rgba(0.67,0.55,1.0,0.50))
                                    : Qt.rgba(1,1,1,0.10)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 80 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: bitVal
                                    font.pixelSize: 8; font.family: Theme.fontMono; font.weight: Font.Bold
                                    color: bitVal === 1 ? "#e8e8ff" : Theme.text3
                                    Behavior on color { ColorAnimation { duration: 80 } }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: toggleBit(bitPos)
                                }
                            }
                        }

                        // bit position labels
                        Text {
                            text: (byteIndex * 8 + 7) + "–" + (byteIndex * 8)
                            width: 28; font.pixelSize: 6; font.family: Theme.fontMono
                            color: Theme.text3; verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignRight; height: 18
                        }
                    }
                }
            }
        }

        // ── Keyboard ─────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true; spacing: 5

            // Row 1: Hex digits + bitwise
            RowLayout {
                Layout.fillWidth: true; spacing: 5
                Repeater {
                    model: ["A","B","C","D","E","F","AND","OR"]
                    delegate: Rectangle {
                        Layout.fillWidth: true; height: 40; radius: 12
                        color: {
                            if (["AND","OR"].indexOf(modelData) >= 0) return Theme.btnOp
                            return (inputBase !== 16) ? Qt.rgba(1,1,1,0.025) : Theme.btnSci
                        }
                        border.color: {
                            if (["AND","OR"].indexOf(modelData) >= 0) return Theme.bdrOp
                            return (inputBase !== 16) ? Qt.rgba(1,1,1,0.05) : Theme.bdrSci
                        }
                        border.width: 1
                        opacity: (["A","B","C","D","E","F"].indexOf(modelData) >= 0 && inputBase !== 16) ? 0.28 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 100 } }
                        scale: ma1.pressed ? 0.88 : 1.0
                        Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }
                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            font.pixelSize: ["AND","OR","XOR","NOT"].indexOf(modelData) >= 0 ? 9 : 13
                            font.family: Theme.fontMono; font.weight: Font.Medium
                            color: ["AND","OR"].indexOf(modelData) >= 0 ? Theme.lblOp : Theme.lblSci
                        }
                        MouseArea {
                            id: ma1; anchors.fill: parent
                            onClicked: {
                                if (["AND","OR"].indexOf(modelData) >= 0) doBitwiseOp(modelData)
                                else appendChar(modelData)
                            }
                        }
                    }
                }
            }

            // Row 2: 7-8-9 + bitwise ops
            RowLayout {
                Layout.fillWidth: true; spacing: 5
                Repeater {
                    model: ["7","8","9","<<",">>","XOR","NOT","CLR"]
                    delegate: Rectangle {
                        Layout.fillWidth: true; height: 44; radius: 12
                        color: {
                            if (modelData === "CLR") return Theme.btnRed
                            if (["<<",">>","XOR","NOT"].indexOf(modelData) >= 0) return Theme.btnOp
                            return Theme.btnNormal
                        }
                        border.color: {
                            if (modelData === "CLR") return Theme.bdrRed
                            if (["<<",">>","XOR","NOT"].indexOf(modelData) >= 0) return Theme.bdrOp
                            return Theme.bdrNormal
                        }
                        border.width: 1
                        scale: ma2.pressed ? 0.88 : 1.0
                        Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }
                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            font.pixelSize: ["<<",">>","XOR","NOT","CLR"].indexOf(modelData) >= 0 ? 9 : 16
                            font.family: Theme.fontMono
                            color: {
                                if (modelData === "CLR") return Theme.lblRed
                                if (["<<",">>","XOR","NOT"].indexOf(modelData) >= 0) return Theme.lblOp
                                return Theme.lblNormal
                            }
                        }
                        MouseArea {
                            id: ma2; anchors.fill: parent
                            onClicked: {
                                if (modelData === "CLR")  doClear()
                                else if (modelData === "NOT") doNOT()
                                else if (["<<",">>","XOR"].indexOf(modelData) >= 0) doBitwiseOp(modelData)
                                else appendChar(modelData)
                            }
                        }
                    }
                }
            }

            // Row 3: 4-5-6 + arith
            RowLayout {
                Layout.fillWidth: true; spacing: 5
                Repeater {
                    model: ["4","5","6","+","-","*","/","DEL"]
                    delegate: Rectangle {
                        Layout.fillWidth: true; height: 44; radius: 12
                        color: ["+","-","*","/"].indexOf(modelData) >= 0 ? Theme.btnOp : Theme.btnNormal
                        border.color: ["+","-","*","/"].indexOf(modelData) >= 0 ? Theme.bdrOp : Theme.bdrNormal
                        border.width: 1
                        scale: ma3.pressed ? 0.88 : 1.0
                        Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }
                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            font.pixelSize: modelData === "DEL" ? 9 : (["+","-","*","/"].indexOf(modelData) >= 0 ? 18 : 16)
                            font.family: Theme.fontMono
                            color: ["+","-","*","/"].indexOf(modelData) >= 0 ? Theme.lblOp : Theme.lblNormal
                        }
                        MouseArea {
                            id: ma3; anchors.fill: parent
                            onClicked: {
                                if (modelData === "DEL") doDelete()
                                else if (["+","-","*","/"].indexOf(modelData) >= 0) doBitwiseOp(modelData)
                                else appendChar(modelData)
                            }
                        }
                    }
                }
            }

            // Row 4: 1-2-3  and  Row 5: 0 + = (wider buttons)
            RowLayout {
                Layout.fillWidth: true; spacing: 5

                // 1 2 3
                Repeater {
                    model: ["1","2","3"]
                    delegate: Rectangle {
                        Layout.fillWidth: true; height: 52; radius: 14
                        color: Theme.btnNormal; border.color: Theme.bdrNormal; border.width: 1
                        scale: maNum.pressed ? 0.88 : 1.0
                        Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }
                        Text { anchors.centerIn: parent; text: modelData; font.pixelSize: 18; font.family: Theme.fontMono; color: Theme.lblNormal }
                        MouseArea { id: maNum; anchors.fill: parent; onClicked: appendChar(modelData) }
                    }
                }

                // 0 (wider)
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredWidth: 80; height: 52; radius: 14
                    color: Theme.btnNormal; border.color: Theme.bdrNormal; border.width: 1
                    scale: maZero.pressed ? 0.88 : 1.0
                    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }
                    Text { anchors.centerIn: parent; text: "0"; font.pixelSize: 18; font.family: Theme.fontMono; color: Theme.lblNormal }
                    MouseArea { id: maZero; anchors.fill: parent; onClicked: appendChar("0") }
                }

                // = (wider, gradient)
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredWidth: 80; height: 52; radius: 14
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Theme.eqA }
                        GradientStop { position: 0.5; color: Theme.eqB }
                        GradientStop { position: 1.0; color: Theme.eqC }
                    }
                    border.color: Theme.bdrEq; border.width: 1
                    scale: maEq.pressed ? 0.88 : 1.0
                    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
                    Text { anchors.centerIn: parent; text: "="; font.pixelSize: 26; font.weight: Font.Light; font.family: Theme.fontMono; color: "#fff" }
                    MouseArea { id: maEq; anchors.fill: parent; onClicked: doEquals() }
                }
            }
        }
    }
}
