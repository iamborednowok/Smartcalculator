import QtQuick
import QtQuick.Layouts
import "components"

Item {
    id: root
    property var window: ApplicationWindow.window

    // ── Graph state ───────────────────────────────────────────────────
    property var  functions: [{ expr: "sin(x)", color: "#7b6fff" }]
    property real xMin: -8; property real xMax: 8
    property real yMin: -5; property real yMax: 5
    property string inputExpr: ""
    property string graphError: ""

    readonly property var graphColors: [
        "#7b6fff","#5dde8a","#f0b84a","#f06060",
        "#5dcdf0","#e060c8","#a0e860","#f080a0"
    ]
    readonly property var presets: [
        "sin(x)","cos(x)","tan(x)","x^2-4",
        "sqrt(abs(x))","1/x","x^3-3*x","exp(-x*x)"
    ]

    // ── Math helpers (pure JS in QML) ─────────────────────────────────
    function evalExpr(expr, x) {
        try {
            var e = expr
                .replace(/\^/g,"**")
                .replace(/\bpi\b/gi, Math.PI)
                .replace(/\be\b/g, Math.E)
                .replace(/\bsin\b/g,"Math.sin")
                .replace(/\bcos\b/g,"Math.cos")
                .replace(/\btan\b/g,"Math.tan")
                .replace(/\bsqrt\b/g,"Math.sqrt")
                .replace(/\bcbrt\b/g,"Math.cbrt")
                .replace(/\babs\b/g,"Math.abs")
                .replace(/\blog\b/g,"Math.log10")
                .replace(/\bln\b/g,"Math.log")
                .replace(/\bexp\b/g,"Math.exp")
                .replace(/\bfloor\b/g,"Math.floor")
                .replace(/\bceil\b/g,"Math.ceil")
            return eval(e.replace(/\bx\b/g, "("+x+")"))
        } catch(e) { return NaN }
    }

    function niceStep(range, divs) {
        var raw  = range / divs
        var exp  = Math.floor(Math.log10(raw))
        var frac = raw / Math.pow(10, exp)
        var nice = frac < 1.5 ? 1 : frac < 3.5 ? 2 : frac < 7.5 ? 5 : 10
        return nice * Math.pow(10, exp)
    }

    function addFunction() {
        var expr = inputExpr.trim()
        if (!expr) return
        // Quick validation
        var test = evalExpr(expr, 1)
        if (isNaN(test) && !isFinite(test)) { graphError = "Invalid — use x as variable"; return }
        var idx = functions.length
        functions = functions.concat([{ expr: expr, color: graphColors[idx % graphColors.length] }])
        inputExpr  = ""
        graphError = ""
        canvas.requestPaint()
    }

    // ── Drag / zoom ───────────────────────────────────────────────────
    property real dragStartX: 0; property real dragStartY: 0
    property real dragStartXMin: 0; property real dragStartXMax: 0
    property real dragStartYMin: 0; property real dragStartYMax: 0
    property bool dragging: false

    // ── UI ────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent; anchors.margins: 14
        spacing: 10

        Text { text: "FUNCTION GRAPHER"; font.pixelSize: 9; color: "#6060a0"; font.letterSpacing: 1 }

        // ── Canvas ────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 230
            radius: 14; clip: true; color: "#06060f"
            border.color: Qt.rgba(1,1,1,0.08); border.width: 1

            Canvas {
                id: canvas
                anchors.fill: parent
                antialiasing: true

                Component.onCompleted: requestPaint()

                onPaint: {
                    var ctx = getContext("2d")
                    var W = width, H = height
                    ctx.clearRect(0, 0, W, H)
                    ctx.fillStyle = "#06060f"
                    ctx.fillRect(0, 0, W, H)

                    function wx(x) { return (x - xMin) / (xMax - xMin) * W }
                    function wy(y) { return H - (y - yMin) / (yMax - yMin) * H }

                    // Grid
                    var xStep = niceStep(xMax - xMin, 8)
                    var yStep = niceStep(yMax - yMin, 6)

                    ctx.strokeStyle = "rgba(255,255,255,0.05)"; ctx.lineWidth = 1
                    for (var x = Math.ceil(xMin/xStep)*xStep; x <= xMax; x += xStep) {
                        ctx.beginPath(); ctx.moveTo(wx(x), 0); ctx.lineTo(wx(x), H); ctx.stroke()
                    }
                    for (var y = Math.ceil(yMin/yStep)*yStep; y <= yMax; y += yStep) {
                        ctx.beginPath(); ctx.moveTo(0, wy(y)); ctx.lineTo(W, wy(y)); ctx.stroke()
                    }

                    // Axes
                    ctx.strokeStyle = "rgba(255,255,255,0.22)"; ctx.lineWidth = 1.5
                    if (xMin < 0 && xMax > 0) {
                        ctx.beginPath(); ctx.moveTo(wx(0), 0); ctx.lineTo(wx(0), H); ctx.stroke()
                    }
                    if (yMin < 0 && yMax > 0) {
                        ctx.beginPath(); ctx.moveTo(0, wy(0)); ctx.lineTo(W, wy(0)); ctx.stroke()
                    }

                    // Labels
                    ctx.font = "10px monospace"; ctx.fillStyle = "rgba(180,180,255,0.35)"
                    ctx.textAlign = "center"
                    for (var lx = Math.ceil(xMin/xStep)*xStep; lx <= xMax; lx += xStep) {
                        if (Math.abs(lx) < xStep * 0.01) continue
                        var py = Math.min(H-5, Math.max(13, wy(0)+12))
                        ctx.fillText(parseFloat(lx.toPrecision(3)), wx(lx), py)
                    }
                    ctx.textAlign = "right"
                    for (var ly = Math.ceil(yMin/yStep)*yStep; ly <= yMax; ly += yStep) {
                        if (Math.abs(ly) < yStep * 0.01) continue
                        var px = Math.min(W-5, Math.max(25, wx(0)-5))
                        ctx.fillText(parseFloat(ly.toPrecision(3)), px, wy(ly)+4)
                    }

                    // Plot each function
                    for (var fi = 0; fi < functions.length; fi++) {
                        var fn = functions[fi]
                        ctx.strokeStyle = fn.color; ctx.lineWidth = 2.5
                        ctx.lineJoin = "round"; ctx.beginPath()
                        var inPath = false; var prevY = null
                        for (var px2 = 0; px2 <= W; px2++) {
                            var fx  = xMin + px2 / W * (xMax - xMin)
                            var fy  = evalExpr(fn.expr, fx)
                            if (!isFinite(fy) || Math.abs(fy) > 1e8) { inPath = false; prevY = null; continue }
                            if (prevY !== null && Math.abs(fy - prevY) > (yMax-yMin)*3) { inPath = false }
                            if (!inPath) { ctx.moveTo(px2, wy(fy)); inPath = true }
                            else         { ctx.lineTo(px2, wy(fy)) }
                            prevY = fy
                        }
                        ctx.stroke()
                    }
                }

                // Pinch-to-zoom
                PinchHandler {
                    onScaleChanged: function() {
                        var cx = (xMin + xMax) / 2, cy = (yMin + yMax) / 2
                        var hw = (xMax - xMin) / 2 / scale, hh = (yMax - yMin) / 2 / scale
                        xMin = cx - hw; xMax = cx + hw; yMin = cy - hh; yMax = cy + hh
                        canvas.requestPaint()
                    }
                }

                // Pan
                DragHandler {
                    onActiveChanged: {
                        if (active) {
                            dragStartXMin = xMin; dragStartXMax = xMax
                            dragStartYMin = yMin; dragStartYMax = yMax
                        }
                    }
                    onTranslationChanged: {
                        var dx = translation.x / canvas.width  * (xMax - xMin)
                        var dy = translation.y / canvas.height * (yMax - yMin)
                        xMin = dragStartXMin - dx; xMax = dragStartXMax - dx
                        yMin = dragStartYMin + dy; yMax = dragStartYMax + dy
                        canvas.requestPaint()
                    }
                }

                // Wheel zoom
                WheelHandler {
                    onWheel: function(event) {
                        var factor = event.angleDelta.y > 0 ? 0.87 : 1.15
                        var cx = (xMin+xMax)/2, cy = (yMin+yMax)/2
                        var hw = (xMax-xMin)/2*factor, hh = (yMax-yMin)/2*factor
                        xMin = cx-hw; xMax = cx+hw; yMin = cy-hh; yMax = cy+hh
                        canvas.requestPaint()
                    }
                }
            }

            // Zoom controls
            Column {
                anchors.right: parent.right; anchors.bottom: parent.bottom
                anchors.margins: 8; spacing: 4

                Repeater {
                    model: ["+","−","⌂"]
                    delegate: Rectangle {
                        width: 28; height: 28; radius: 8
                        color: Qt.rgba(1,1,1,0.10); border.color: Qt.rgba(1,1,1,0.18); border.width: 1
                        Text { anchors.centerIn: parent; text: modelData; color: "#a0a0c8"; font.pixelSize: 13 }
                        MouseArea { anchors.fill: parent
                            onClicked: {
                                if (modelData === "⌂") { xMin=-8;xMax=8;yMin=-5;yMax=5 }
                                else {
                                    var f = modelData==="+" ? 0.7 : 1.43
                                    var cx=(xMin+xMax)/2, cy=(yMin+yMax)/2
                                    xMin=cx-(xMax-xMin)/2*f; xMax=cx+(xMax-xMin)/2*f
                                    yMin=cy-(yMax-yMin)/2*f; yMax=cy+(yMax-yMin)/2*f
                                }
                                canvas.requestPaint()
                            }
                        }
                    }
                }
            }

            Text {
                anchors.top: parent.top; anchors.left: parent.left
                anchors.margins: 8; text: "drag · scroll to zoom"
                font.pixelSize: 8; color: "rgba(255,255,255,0.18)"
            }
        }

        // ── Function list ─────────────────────────────────────────────
        Repeater {
            model: functions
            delegate: Rectangle {
                Layout.fillWidth: true; height: 34; radius: 9
                color: Qt.rgba(1,1,1,0.06); border.color: Qt.rgba(1,1,1,0.09); border.width: 1

                RowLayout {
                    anchors.fill: parent; anchors.margins: 10; spacing: 8

                    Rectangle { width: 10; height: 10; radius: 5; color: modelData.color }
                    Text { text: "y = " + modelData.expr; color: "#f0f0ff"; font.pixelSize: 12
                        font.family: "JetBrains Mono"; Layout.fillWidth: true; elide: Text.ElideRight }

                    Rectangle {
                        width: 22; height: 22; radius: 6
                        color: "transparent"; border.color: Qt.rgba(1,1,1,0.14); border.width: 1
                        Text { anchors.centerIn: parent; text: "✕"; color: "#60609a"; font.pixelSize: 10 }
                        MouseArea { anchors.fill: parent
                            onClicked: {
                                var arr = []; for (var i=0;i<functions.length;i++) if(i!==index) arr.push(functions[i])
                                functions = arr; canvas.requestPaint()
                            }
                        }
                    }
                }
            }
        }

        // ── Add function row ──────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true; spacing: 8

            StyledInput {
                id: exprInput
                Layout.fillWidth: true
                placeholderText: "e.g. sin(x), x^2-4, tan(x)"
                text: inputExpr
                onTextChanged: inputExpr = text
                Keys.onReturnPressed: addFunction()
            }

            Rectangle {
                width: 64; height: 42; radius: 10
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#5b50f2" }
                    GradientStop { position: 1.0; color: "#7c3aed" }
                }
                Text { anchors.centerIn: parent; text: "+ Add"; color: "#fff"; font.pixelSize: 12; font.weight: Font.DemiBold }
                MouseArea { anchors.fill: parent; onClicked: addFunction() }
            }
        }

        Text { visible: graphError !== ""; text: graphError; color: "#f08080"; font.pixelSize: 10 }

        // ── Presets ───────────────────────────────────────────────────
        Text { text: "PRESETS"; font.pixelSize: 9; color: "#5858a0"; font.letterSpacing: 1 }
        Flow {
            Layout.fillWidth: true; spacing: 6
            Repeater {
                model: presets
                delegate: Rectangle {
                    width: lbl.implicitWidth + 16; height: 26; radius: 8
                    color: Qt.rgba(1,1,1,0.06); border.color: Qt.rgba(1,1,1,0.09); border.width: 1
                    Text { id: lbl; anchors.centerIn: parent; text: modelData
                        font.pixelSize: 10; color: "#a0a0c8"; font.family: "JetBrains Mono" }
                    MouseArea { anchors.fill: parent
                        onClicked: {
                            for (var i=0; i<functions.length; i++) if(functions[i].expr === modelData) return
                            var idx = functions.length
                            functions = functions.concat([{ expr: modelData, color: graphColors[idx % graphColors.length] }])
                            canvas.requestPaint()
                        }
                    }
                }
            }
        }

        // Clear all
        Rectangle {
            visible: functions.length > 0
            width: 70; height: 26; radius: 8
            color: "transparent"; border.color: Qt.rgba(1,1,1,0.12); border.width: 1
            Text { anchors.centerIn: parent; text: "clear all"; font.pixelSize: 9; color: "#8888b8" }
            MouseArea { anchors.fill: parent; onClicked: { functions = []; canvas.requestPaint() } }
        }

        Item { Layout.fillHeight: true }
    }

    // Re-paint whenever view bounds change
    onXMinChanged: canvas.requestPaint()
    onXMaxChanged: canvas.requestPaint()
    onYMinChanged: canvas.requestPaint()
    onYMaxChanged: canvas.requestPaint()
}
