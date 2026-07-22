import QtQuick
import QtQuick.Layouts
import "components"

Item {
    id: root
    property var window: ApplicationWindow.window

    // ── Entrance animation (plays each time this tab becomes current) ──
    // A quick fade + gentle pop-in on switching to this tab instead of
    // just snapping into view — see Theme.popDuration/popEasing.
    opacity: 1.0
    scale: 1.0
    // Driven from Main.qml (root.currentTab === <this tab's index>), not
    // StackLayout.isCurrentItem — this tab is now lazy-loaded through a
    // Loader (see Main.qml), so it's a grandchild of StackLayout rather
    // than a direct child, and StackLayout only ever sets that attached
    // property on its own direct children. A plain external property
    // sidesteps that entirely and works regardless of nesting.
    property bool isCurrentTab: false
    onIsCurrentTabChanged: if (isCurrentTab) { enterFade.restart(); enterScale.restart() }
    NumberAnimation { id: enterFade;  target: root; property: "opacity"; from: 0.0;  to: 1.0; duration: Theme.popDuration; easing.type: Easing.OutQuad }
    NumberAnimation { id: enterScale; target: root; property: "scale";   from: 0.97; to: 1.0; duration: Theme.popDuration; easing.type: Theme.popEasing; easing.overshoot: Theme.popOvershoot }

    property var  functions: [{ expr: "sin(x)", color: Theme.accent }]
    property real xMin: -8; property real xMax: 8
    property real yMin: -5; property real yMax: 5
    property string inputExpr: ""
    property string graphError: ""

    // Small fixed palette so multiple plotted curves stay distinguishable —
    // this is plot/content coloring (like a chart legend), not app theming,
    // so only the first entry is driven by Theme (see comment below); the
    // other 7 are deliberately fixed so re-theming the app never scrambles
    // an in-progress multi-function graph.
    readonly property var graphColors: [
        Theme.accent, // BUG FIX: was a duplicated "#FF4D2E" literal that
                      // silently went stale the moment Theme.accent changed
                      // (the default curve above already referenced
                      // Theme.accent directly — this now actually matches it,
                      // including for the first *added* function, not just
                      // the pre-loaded one).
        "#F4653B", "#F4B740", "#1B9E5E",
        "#22D3EE", "#2F7BFF", "#8B5CF6", "#D63BA8"
    ]
    readonly property var presets: [
        "sin(x)","cos(x)","tan(x)","x^2-4",
        "sqrt(abs(x))","1/x","x^3-3*x","exp(-x*x)"
    ]

    // evalExpr — delegates to MathEngine.evaluateAt() on the C++ side
    // (unchanged from the original; expression parsing/safety lives there).
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
        anchors.fill: parent
        anchors.margins: Theme.sp4
        spacing: Theme.sp3

        // ── Header ───────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Graph"
                font.family: Theme.fontSans
                font.weight: Font.DemiBold
                font.pixelSize: Math.round(16 * Theme.scale)
                color: Theme.text
            }
            Item { Layout.fillWidth: true }
            Text {
                text: "reset view"
                color: Theme.textDim
                font.family: Theme.fontSans
                font.pixelSize: Math.round(12 * Theme.scale)
                TapHandler { onTapped: { xMin=-8; xMax=8; yMin=-5; yMax=5; canvas.requestPaint() } }
            }
        }

        // ── Canvas — fills available height; this is the variable-height
        // payload of the tab, so unlike Calc/Convert it's allowed to grow ──
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: Math.round(200 * Theme.scale)
            radius: Theme.rMd
            clip: true
            color: Theme.surface

            // Neon rim (both modes — see Theme.edgeB2)
            Rectangle {
                anchors.fill: parent; anchors.margins: -1
                radius: parent.radius + 1
                color: "transparent"
                border.width: 1; border.color: Theme.edgeB2
            }

            Canvas {
                id: canvas
                anchors.fill: parent
                antialiasing: true

                Component.onCompleted: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                Connections {
                    target: Theme
                    function onDarkChanged() { canvas.requestPaint() }
                }

                onPaint: {
                    var ctx = getContext("2d")
                    var W = width, H = height
                    ctx.clearRect(0, 0, W, H)
                    ctx.fillStyle = Theme.surface.toString()
                    ctx.fillRect(0, 0, W, H)

                    function wx(x) { return (x - xMin) / (xMax - xMin) * W }
                    function wy(y) { return H - (y - yMin) / (yMax - yMin) * H }

                    var xStep = niceStep(xMax - xMin, 8)
                    var yStep = niceStep(yMax - yMin, 6)

                    // Grid
                    ctx.strokeStyle = Theme.dark ? "rgba(255,255,255,0.06)" : "rgba(0,0,0,0.06)"; ctx.lineWidth = 1
                    for (var gx = Math.ceil(xMin/xStep)*xStep; gx <= xMax; gx += xStep) {
                        ctx.beginPath(); ctx.moveTo(wx(gx), 0); ctx.lineTo(wx(gx), H); ctx.stroke()
                    }
                    for (var gy = Math.ceil(yMin/yStep)*yStep; gy <= yMax; gy += yStep) {
                        ctx.beginPath(); ctx.moveTo(0, wy(gy)); ctx.lineTo(W, wy(gy)); ctx.stroke()
                    }

                    // Axes
                    ctx.strokeStyle = Theme.dark ? "rgba(255,255,255,0.26)" : "rgba(0,0,0,0.24)"; ctx.lineWidth = 1.5
                    if (xMin < 0 && xMax > 0) {
                        ctx.beginPath(); ctx.moveTo(wx(0), 0); ctx.lineTo(wx(0), H); ctx.stroke()
                    }
                    if (yMin < 0 && yMax > 0) {
                        ctx.beginPath(); ctx.moveTo(0, wy(0)); ctx.lineTo(W, wy(0)); ctx.stroke()
                    }

                    // Labels
                    ctx.font = "10px monospace"; ctx.fillStyle = Theme.dark ? "rgba(245,245,242,0.34)" : "rgba(21,21,26,0.34)"
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
                    // PERF FIX: this used to call evalExpr() — a full
                    // QML→C++ evaluateAt() round trip — once per horizontal
                    // pixel per function (400-1000+ calls per function per
                    // repaint on a typical phone width, each one re-running
                    // MathEngine's expression.simplified() on the same
                    // unchanged string). mathEngine.evaluateRange() takes
                    // the whole sample range in one native call instead —
                    // same GParser, same math, same NaN-on-error behavior
                    // per point, see MathEngine.cpp.
                    for (var fi = 0; fi < functions.length; fi++) {
                        var fn = functions[fi]
                        ctx.strokeStyle = fn.color; ctx.lineWidth = 2.2
                        ctx.lineJoin = "round"; ctx.beginPath()
                        var ys = mathEngine.evaluateRange(fn.expr, xMin, xMax, W)
                        var inPath = false; var prevFy = null
                        for (var px2 = 0; px2 <= W; px2++) {
                            var fy = ys[px2]
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
                        var fp = pinch.centroid.position
                        var px = xMin + (fp.x / canvas.width)  * (xMax - xMin)
                        var py = yMax - (fp.y / canvas.height) * (yMax - yMin)
                        xMin = px - (px - xMin) / delta;  xMax = px + (xMax - px) / delta
                        yMin = py - (py - yMin) / delta;  yMax = py + (yMax - py) / delta
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
                anchors.margins: Theme.sp2
                spacing: Theme.sp1

                Repeater {
                    model: ["+","−"]
                    delegate: Rectangle {
                        width: Math.round(30 * Theme.scale); height: width; radius: Theme.rSm
                        color: Theme.bg
                        opacity: 0.9
                        Text { anchors.centerIn: parent; text: modelData; color: Theme.textDim; font.family: Theme.fontMono; font.pixelSize: Math.round(14 * Theme.scale) }
                        TapHandler {
                            onTapped: {
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
                anchors.margins: Theme.sp2
                text: "drag · pinch · scroll"
                font.family: Theme.fontSans
                font.pixelSize: Math.round(9 * Theme.scale)
                color: Theme.textFaint
            }
        }

        // ── Function chips ─────────────────────────────────────────────
        Flickable {
            Layout.fillWidth: true
            height: functions.length > 0 ? Math.round(34 * Theme.scale) : 0
            visible: height > 0
            contentWidth: fnRow.implicitWidth
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Row {
                id: fnRow
                spacing: Theme.sp2
                height: parent.height
                Repeater {
                    model: functions
                    delegate: Rectangle {
                        height: Math.round(30 * Theme.scale)
                        width: fnLbl.implicitWidth + Theme.sp4 * 2
                        radius: Theme.rFull
                        color: Theme.surface
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: Theme.sp1
                            Rectangle { width: Math.round(8 * Theme.scale); height: width; radius: width/2; color: modelData.color }
                            Text { id: fnLbl; text: "y = " + modelData.expr; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: Math.round(11 * Theme.scale) }
                            Text {
                                text: "✕"; color: Theme.textFaint; font.pixelSize: Math.round(10 * Theme.scale)
                                TapHandler {
                                    onTapped: {
                                        var arr = []; for (var i=0;i<functions.length;i++) if(i!==index) arr.push(functions[i])
                                        functions = arr; canvas.requestPaint()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Add function row ────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp2

            StyledInput {
                id: exprInput
                Layout.fillWidth: true
                placeholderText: "e.g. sin(x), x^2-4, tan(x)"
                text: inputExpr
                onTextChanged: inputExpr = text
                Keys.onReturnPressed: addFunction()
            }
            Rectangle {
                id: addBtn
                width: Math.round(60 * Theme.scale); height: Math.round(44 * Theme.scale); radius: Theme.rMd
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Theme.gradA }
                    GradientStop { position: 0.5; color: Theme.gradB }
                    GradientStop { position: 1.0; color: Theme.gradC }
                }
                Rectangle {
                    anchors.fill: parent; anchors.margins: -2; radius: parent.radius + 2
                    color: "transparent"; border.width: 2; border.color: Theme.edgeA
                }
                Text { anchors.centerIn: parent; text: "Add"; color: Theme.textOnAccent; font.family: Theme.fontSans; font.weight: Font.DemiBold; font.pixelSize: Math.round(13 * Theme.scale) }

                scale: 1.0
                NumberAnimation { id: addPressDown;  target: addBtn; property: "scale"; to: 0.92; duration: Theme.press; easing.type: Easing.OutQuad }
                NumberAnimation { id: addBounceBack; target: addBtn; property: "scale"; to: 1.0;  duration: Theme.bounceDuration; easing.type: Theme.bounceEasing; easing.overshoot: Theme.bounceOvershoot }
                TapHandler {
                    onPressedChanged: {
                        if (pressed) { addBounceBack.stop(); addPressDown.restart() }
                        else { addPressDown.stop(); addBounceBack.restart() }
                    }
                    onTapped: addFunction()
                }
            }
        }

        Text {
            visible: graphError !== ""
            text: "⚠ " + graphError
            color: Theme.accent
            font.family: Theme.fontSans
            font.pixelSize: Math.round(11 * Theme.scale)
        }

        // ── Presets ─────────────────────────────────────────────────────
        Flickable {
            Layout.fillWidth: true
            height: Math.round(30 * Theme.scale)
            contentWidth: presetRow.implicitWidth
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Row {
                id: presetRow
                spacing: Theme.sp4
                height: parent.height
                Repeater {
                    model: presets
                    delegate: Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData
                        color: Theme.accent2
                        font.family: Theme.fontMono
                        font.pixelSize: Math.round(12 * Theme.scale)
                        TapHandler {
                            onTapped: {
                                for (var i=0; i<functions.length; i++) if(functions[i].expr === modelData) return
                                var idx = functions.length
                                functions = functions.concat([{ expr: modelData, color: graphColors[idx % graphColors.length] }])
                                canvas.requestPaint()
                            }
                        }
                    }
                }
            }
        }
    }

    onXMinChanged: if (!repaintTimer.running) canvas.requestPaint()
    onXMaxChanged: if (!repaintTimer.running) canvas.requestPaint()
    onYMinChanged: if (!repaintTimer.running) canvas.requestPaint()
    onYMaxChanged: if (!repaintTimer.running) canvas.requestPaint()
}
