import QtQuick
import QtQuick.Layouts
import "components"

Item {
    id: root
    property var window: ApplicationWindow.window

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

    // evalExpr — delegates to MathEngine.evaluateAt() on the C++ side.
    // This eliminates the raw Function/eval surface for graph expressions:
    // user input is passed as a data property, never interpolated into JS source.
    function evalExpr(expr, x) {
        try {
            var result = mathEngine.evaluateAt(expr, x)
            return isNaN(result) ? NaN : result
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
        // Test several x values — a function like sqrt(x-2) is NaN at x=1
        // but perfectly valid for x>=2. Accept if ANY probe returns finite.
        var probeXs = [-5, -2, -1, 0, 1, 2, 5]
        var anyFinite = false
        for (var pi = 0; pi < probeXs.length; pi++) {
            var v = evalExpr(expr, probeXs[pi])
            if (isFinite(v) && !isNaN(v)) { anyFinite = true; break }
        }
        if (!anyFinite) { graphError = "Invalid — use x as variable"; return }
        var idx = functions.length
        functions = functions.concat([{ expr: expr, color: graphColors[idx % graphColors.length] }])
        inputExpr  = ""
        graphError = ""
        canvas.requestPaint()
    }

    // Drag / zoom state
    property real dragStartXMin: 0; property real dragStartXMax: 0
    property real dragStartYMin: 0; property real dragStartYMax: 0

    // PERF FIX: Throttle canvas repaints during rapid pan/zoom to 50ms.
    // Without this, every pointer move event triggers a synchronous repaint
    // which tanks frame rate on mobile during drag.
    Timer {
        id: repaintTimer
        interval: 50; repeat: false
        onTriggered: canvas.requestPaint()
    }
    function scheduleRepaint() { if (!repaintTimer.running) repaintTimer.restart() }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 14
        spacing: 10

        // ── Header ────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Column {
                spacing: 3
                Row {
                    spacing: 0
                    Text { text: "Function"; font.pixelSize: Math.round(18 * Theme.scale); font.family: Theme.fontSans; font.weight: Font.Light; color: Theme.text2 }
                    Text { text: " Grapher"; font.pixelSize: Math.round(18 * Theme.scale); font.family: Theme.fontSans; font.weight: Font.Bold; color: Theme.accent2 }
                }
                Rectangle {
                    width: 42; height: 2; radius: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#7C3AED" }
                        GradientStop { position: 1.0; color: "#06B6D4" }
                    }
                }
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                height: 26; width: resetLbl.implicitWidth + 18; radius: 13
                color: Qt.rgba(1,1,1,0.05); border.color: Theme.border1; border.width: 1
                Text { id: resetLbl; anchors.centerIn: parent; text: "⌂ reset view"; font.pixelSize: Math.round(9 * Theme.scale); color: Theme.actionLabel; font.family: Theme.fontSans }
                MouseArea { anchors.fill: parent; onClicked: { xMin=-8;xMax=8;yMin=-5;yMax=5; canvas.requestPaint() } }
            }
        }

        // ── Canvas ────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 220
            radius: 16; clip: true; color: Theme.dark ? "#04040e" : "#e8f4fd"
            border.color: Theme.sectionBdr; border.width: 1

            // Inner top sheen
            Rectangle {
                anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.45; height: 1; y: 1; radius: 1
                color: Qt.rgba(1,1,1,0.10)
            }

            Canvas {
                id: canvas
                anchors.fill: parent
                antialiasing: true

                Component.onCompleted: requestPaint()
                onWidthChanged: requestPaint()

                // Repaint when the user switches dark/light theme
                Connections {
                    target: Theme
                    function onDarkChanged() { canvas.requestPaint() }
                }

                onPaint: {
                    var ctx = getContext("2d")
                    var W = width, H = height
                    ctx.clearRect(0, 0, W, H)
                    ctx.fillStyle = Theme.dark ? "#04040e" : "#e8f4fd"
                    ctx.fillRect(0, 0, W, H)

                    function wx(x) { return (x - xMin) / (xMax - xMin) * W }
                    function wy(y) { return H - (y - yMin) / (yMax - yMin) * H }

                    var xStep = niceStep(xMax - xMin, 8)
                    var yStep = niceStep(yMax - yMin, 6)

                    // Grid
                    ctx.strokeStyle = Theme.dark ? "rgba(255,255,255,0.055)" : "rgba(10,74,140,0.08)"; ctx.lineWidth = 1
                    for (var gx = Math.ceil(xMin/xStep)*xStep; gx <= xMax; gx += xStep) {
                        ctx.beginPath(); ctx.moveTo(wx(gx), 0); ctx.lineTo(wx(gx), H); ctx.stroke()
                    }
                    for (var gy = Math.ceil(yMin/yStep)*yStep; gy <= yMax; gy += yStep) {
                        ctx.beginPath(); ctx.moveTo(0, wy(gy)); ctx.lineTo(W, wy(gy)); ctx.stroke()
                    }

                    // Axes
                    ctx.strokeStyle = Theme.dark ? "rgba(255,255,255,0.24)" : "rgba(10,74,140,0.32)"; ctx.lineWidth = 1.5
                    if (xMin < 0 && xMax > 0) {
                        ctx.beginPath(); ctx.moveTo(wx(0), 0); ctx.lineTo(wx(0), H); ctx.stroke()
                    }
                    if (yMin < 0 && yMax > 0) {
                        ctx.beginPath(); ctx.moveTo(0, wy(0)); ctx.lineTo(W, wy(0)); ctx.stroke()
                    }

                    // Labels
                    ctx.font = "10px monospace"; ctx.fillStyle = Theme.dark ? "rgba(180,180,255,0.32)" : "rgba(10,74,140,0.35)"
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

                    // Plot functions
                    for (var fi = 0; fi < functions.length; fi++) {
                        var fn = functions[fi]
                        ctx.strokeStyle = fn.color; ctx.lineWidth = 2.2
                        ctx.lineJoin = "round"; ctx.beginPath()
                        var inPath = false; var prevFy = null
                        for (var px2 = 0; px2 <= W; px2++) {
                            var fx  = xMin + px2 / W * (xMax - xMin)
                            var fy  = evalExpr(fn.expr, fx)
                            if (!isFinite(fy) || Math.abs(fy) > 1e8) { inPath = false; prevFy = null; continue }
                            if (prevFy !== null && Math.abs(fy - prevFy) > (yMax-yMin)*3) { inPath = false }
                            if (!inPath) { ctx.moveTo(px2, wy(fy)); inPath = true }
                            else         { ctx.lineTo(px2, wy(fy)) }
                            prevFy = fy
                        }
                        ctx.stroke()
                    }
                }

                PinchHandler {
                    id: pinch
                    property real lastScale: 1.0
                    onActiveChanged: if (active) lastScale = 1.0
                    onScaleChanged: {
                        var delta = scale / lastScale
                        lastScale = scale
                        // FIX #18: pivot on pinch centroid in graph-space, not viewport center.
                        // Keeps the point under the fingers stationary during zoom.
                        var fp = pinch.centroid.position
                        var px = xMin + (fp.x / canvas.width)  * (xMax - xMin)
                        var py = yMax - (fp.y / canvas.height) * (yMax - yMin)
                        xMin = px - (px - xMin) / delta;  xMax = px + (xMax - px) / delta
                        yMin = py - (py - yMin) / delta;  yMax = py + (yMax - py) / delta
                        // FIX #26: clamp to minimum range to prevent degenerate viewport
                        var MIN_RANGE = 1e-9
                        if (xMax - xMin < MIN_RANGE) { var midX=(xMin+xMax)/2; xMin=midX-MIN_RANGE/2; xMax=midX+MIN_RANGE/2 }
                        if (yMax - yMin < MIN_RANGE) { var midY=(yMin+yMax)/2; yMin=midY-MIN_RANGE/2; yMax=midY+MIN_RANGE/2 }
                        scheduleRepaint()
                    }
                }

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
                        scheduleRepaint()
                    }
                }

                WheelHandler {
                    onWheel: function(event) {
                        var factor = event.angleDelta.y > 0 ? 0.87 : 1.15
                        // FIX #18: pivot on cursor position in graph-space, not viewport center.
                        var px = xMin + (event.x / canvas.width)  * (xMax - xMin)
                        var py = yMax - (event.y / canvas.height) * (yMax - yMin)
                        xMin = px - (px - xMin) * factor;  xMax = px + (xMax - px) * factor
                        yMin = py - (py - yMin) * factor;  yMax = py + (yMax - py) * factor
                        // FIX #26: clamp to minimum range to prevent degenerate viewport
                        var MIN_RANGE = 1e-9
                        if (xMax - xMin < MIN_RANGE) { var midX=(xMin+xMax)/2; xMin=midX-MIN_RANGE/2; xMax=midX+MIN_RANGE/2 }
                        if (yMax - yMin < MIN_RANGE) { var midY=(yMin+yMax)/2; yMin=midY-MIN_RANGE/2; yMax=midY+MIN_RANGE/2 }
                        scheduleRepaint()
                    }
                }
            }

            // Zoom controls
            Column {
                anchors.right: parent.right; anchors.bottom: parent.bottom
                anchors.margins: 8; spacing: 4

                Repeater {
                    model: ["+","−"]
                    delegate: Rectangle {
                        width: 30; height: 30; radius: 10
                        color: Theme.border1; border.color: Theme.border2; border.width: 1
                        Text { anchors.centerIn: parent; text: modelData; color: Theme.text2; font.pixelSize: Math.round(14 * Theme.scale); font.family: Theme.fontMono }
                        MouseArea { anchors.fill: parent
                            onClicked: {
                                var f = modelData==="+" ? 0.70 : 1.43
                                var cx=(xMin+xMax)/2, cy=(yMin+yMax)/2
                                xMin=cx-(xMax-xMin)/2*f; xMax=cx+(xMax-xMin)/2*f
                                yMin=cy-(yMax-yMin)/2*f; yMax=cy+(yMax-yMin)/2*f
                                // FIX #30: match Fix #26 clamp — repeated "+" taps can drive
                                // the range below 1e-9, causing identical degenerate-viewport
                                // bugs (blank canvas, NaN axis labels) that Fix #26 patched
                                // for PinchHandler/WheelHandler but missed here.
                                var MIN_RANGE = 1e-9
                                if (xMax - xMin < MIN_RANGE) { var midX=(xMin+xMax)/2; xMin=midX-MIN_RANGE/2; xMax=midX+MIN_RANGE/2 }
                                if (yMax - yMin < MIN_RANGE) { var midY=(yMin+yMax)/2; yMin=midY-MIN_RANGE/2; yMax=midY+MIN_RANGE/2 }
                                scheduleRepaint()
                            }
                        }
                    }
                }
            }

            Text {
                anchors.top: parent.top; anchors.left: parent.left
                anchors.margins: 9; text: "drag · pinch · scroll"
                font.pixelSize: Math.round(8 * Theme.scale); color: Qt.rgba(1,1,1, Theme.dark ? 0.16 : 0)
                font.family: Theme.fontSans
            }
        }

        // ── Function list ─────────────────────────────────────────────
        Repeater {
            model: functions
            delegate: Rectangle {
                Layout.fillWidth: true; height: 36; radius: 10
                color: Theme.sectionBg; border.color: Theme.border1; border.width: 1

                RowLayout {
                    anchors.fill: parent; anchors.margins: 10; spacing: 8

                    Rectangle { width: 10; height: 10; radius: 5; color: modelData.color }
                    Text { text: "y = " + modelData.expr; color: Theme.text; font.pixelSize: Math.round(12 * Theme.scale)
                        font.family: Theme.fontMono; Layout.fillWidth: true; elide: Text.ElideRight }

                    Rectangle {
                        width: 24; height: 24; radius: 7
                        color: "transparent"; border.color: Qt.rgba(1,1,1,0.14); border.width: 1
                        Text { anchors.centerIn: parent; text: "✕"; color: "#60609a"; font.pixelSize: Math.round(10 * Theme.scale) }
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
                width: 68; height: 44; radius: 12
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#5b50f2" }
                    GradientStop { position: 1.0; color: "#7c3aed" }
                }
                border.color: Qt.rgba(0.80,0.60,1.0,0.30); border.width: 1
                Text { anchors.centerIn: parent; text: "+ Add"; color: "#fff"; font.pixelSize: Math.round(12 * Theme.scale); font.family: Theme.fontSans; font.weight: Font.DemiBold }
                MouseArea { anchors.fill: parent; onClicked: addFunction() }
            }
        }

        Text { visible: graphError !== ""; text: "⚠  " + graphError; color: Theme.red; font.pixelSize: Math.round(10 * Theme.scale); font.family: Theme.fontSans }

        // ── Presets ───────────────────────────────────────────────────
        Text { text: "PRESETS"; font.pixelSize: Math.round(8 * Theme.scale); color: "#484878"; font.letterSpacing: 1; font.family: Theme.fontSans }
        Flow {
            Layout.fillWidth: true; spacing: 6
            Repeater {
                model: presets
                delegate: Rectangle {
                    width: lbl.implicitWidth + 18; height: 28; radius: 9
                    color: Theme.sectionBg; border.color: Theme.border1; border.width: 1
                    Text { id: lbl; anchors.centerIn: parent; text: modelData
                        font.pixelSize: Math.round(10 * Theme.scale); color: "#9898c8"; font.family: Theme.fontMono }
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

        Rectangle {
            visible: functions.length > 0
            width: 74; height: 27; radius: 9
            color: "transparent"; border.color: Qt.rgba(1,1,1,0.11); border.width: 1
            Text { anchors.centerIn: parent; text: "clear all"; font.pixelSize: Math.round(9 * Theme.scale); color: "#8080b0"; font.family: Theme.fontSans }
            MouseArea { anchors.fill: parent; onClicked: { functions = []; canvas.requestPaint() } }
        }

        Item { Layout.fillHeight: true }
    }

    // Repaint when bounds change (from keyboard/button input, not drag — those use scheduleRepaint)
    onXMinChanged: if (!repaintTimer.running) canvas.requestPaint()
    onXMaxChanged: if (!repaintTimer.running) canvas.requestPaint()
    onYMinChanged: if (!repaintTimer.running) canvas.requestPaint()
    onYMaxChanged: if (!repaintTimer.running) canvas.requestPaint()
}
