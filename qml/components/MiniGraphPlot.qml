import QtQuick

// ── In-chat graph view ──────────────────────────────────────────────────
// Renders the plot for AI's "plot_graph" skill (see AITab.qml's
// systemPrompt + extractGraphExprs()) directly inside the chat bubble —
// this IS the answer, not a teaser for the full Graph tab, so it carries
// real grid lines and axis tick labels rather than a bare curve.
//
// Still deliberately NOT a reuse of GraphTab's Canvas — GraphTab's canvas
// carries pan/zoom drag handlers, a preset bar, and a pile of full-tab UI
// state a chat-bubble plot has no use for. This is the read-only subset:
// grid + axes + tick labels + curves + legend, auto-fit view.
//
// The color palette intentionally mirrors GraphTab.graphColors exactly
// (same literals, same order) so a function plotted here reads the same
// way it would in the full Graph tab. Same kind of intentional
// fixed-palette duplication GraphTab.graphColors itself calls out in
// REBUILD_NOTES.md — chart/content coloring, not app theming, so it's not
// routed through Theme.
Item {
    id: root
    property var expressions: []   // array of expr strings, e.g. ["sin(x)", "x^2-4"]
    property real xMin: -8
    property real xMax: 8
    property real yMin: -5
    property real yMax: 5

    implicitHeight: Math.round(170 * Theme.scale)

    readonly property var graphColors: [
        Theme.accent, "#F4653B", "#F4B740", "#1B9E5E",
        "#22D3EE", "#2F7BFF", "#8B5CF6", "#D63BA8"
    ]

    // Same "pick a round-looking step" logic as GraphTab.niceStep() —
    // duplicated rather than imported since it's a 6-line pure function
    // and GraphTab.qml doesn't expose it as a shared utility.
    function niceStep(range, divs) {
        var raw  = range / divs
        var exp  = Math.floor(Math.log10(raw))
        var frac = raw / Math.pow(10, exp)
        var nice = frac < 1.5 ? 1 : frac < 3.5 ? 2 : frac < 7.5 ? 5 : 10
        return nice * Math.pow(10, exp)
    }

    // Auto-fit the y-range to what's actually plotted over [xMin, xMax] —
    // a fixed -5..5 window would clip x^2 or flatten 1/x into a spike.
    // Cheap: 60 samples per expression, run once per expressions change,
    // not per repaint.
    function autoFitY() {
        var lo = Infinity, hi = -Infinity
        for (var i = 0; i < expressions.length; i++) {
            var ys = mathEngine.evaluateRange(expressions[i], xMin, xMax, 60)
            for (var j = 0; j < ys.length; j++) {
                var v = ys[j]
                if (isFinite(v) && Math.abs(v) < 1e6) { if (v < lo) lo = v; if (v > hi) hi = v }
            }
        }
        if (!isFinite(lo) || !isFinite(hi)) return   // nothing finite sampled — keep default window
        if (lo === hi) { lo -= 1; hi += 1 }            // flat line (e.g. a constant) — give it visible headroom
        var pad = (hi - lo) * 0.18
        yMin = lo - pad
        yMax = hi + pad
    }

    onExpressionsChanged: { autoFitY(); canvas.requestPaint() }
    Component.onCompleted: { autoFitY(); canvas.requestPaint() }

    Rectangle {
        anchors.fill: parent
        radius: Theme.rMd
        color: Theme.surface
        clip: true

        Canvas {
            id: canvas
            anchors.fill: parent
            antialiasing: true
            onWidthChanged:  requestPaint()
            onHeightChanged: requestPaint()
            Connections { target: Theme; function onDarkChanged() { canvas.requestPaint() } }

            onPaint: {
                var ctx = getContext("2d")
                var W = width, H = height
                ctx.clearRect(0, 0, W, H)

                function wx(x) { return (x - root.xMin) / (root.xMax - root.xMin) * W }
                function wy(y) { return H - (y - root.yMin) / (root.yMax - root.yMin) * H }

                var xStep = root.niceStep(root.xMax - root.xMin, 6)
                var yStep = root.niceStep(root.yMax - root.yMin, 4)

                // Grid
                ctx.strokeStyle = Theme.dark ? "rgba(255,255,255,0.06)" : "rgba(0,0,0,0.06)"
                ctx.lineWidth = 1
                for (var gx = Math.ceil(root.xMin/xStep)*xStep; gx <= root.xMax; gx += xStep) {
                    ctx.beginPath(); ctx.moveTo(wx(gx), 0); ctx.lineTo(wx(gx), H); ctx.stroke()
                }
                for (var gy = Math.ceil(root.yMin/yStep)*yStep; gy <= root.yMax; gy += yStep) {
                    ctx.beginPath(); ctx.moveTo(0, wy(gy)); ctx.lineTo(W, wy(gy)); ctx.stroke()
                }

                // Axes
                ctx.strokeStyle = Theme.dark ? "rgba(255,255,255,0.24)" : "rgba(0,0,0,0.22)"
                ctx.lineWidth = 1.3
                if (root.xMin < 0 && root.xMax > 0) {
                    ctx.beginPath(); ctx.moveTo(wx(0), 0); ctx.lineTo(wx(0), H); ctx.stroke()
                }
                if (root.yMin < 0 && root.yMax > 0) {
                    ctx.beginPath(); ctx.moveTo(0, wy(0)); ctx.lineTo(W, wy(0)); ctx.stroke()
                }

                // Tick labels — small monospace, skipped right at the
                // origin (the axis lines already mark it) and clamped
                // to stay on-canvas near the edges.
                ctx.font = "9px monospace"
                ctx.fillStyle = Theme.dark ? "rgba(245,245,242,0.4)" : "rgba(21,21,26,0.4)"
                ctx.textAlign = "center"
                for (var lx = Math.ceil(root.xMin/xStep)*xStep; lx <= root.xMax; lx += xStep) {
                    if (Math.abs(lx) < xStep * 0.01) continue
                    var py = Math.min(H-4, Math.max(11, wy(0)+11))
                    ctx.fillText(parseFloat(lx.toPrecision(3)), wx(lx), py)
                }
                ctx.textAlign = "right"
                for (var ly = Math.ceil(root.yMin/yStep)*yStep; ly <= root.yMax; ly += yStep) {
                    if (Math.abs(ly) < yStep * 0.01) continue
                    var px2 = Math.min(W-4, Math.max(22, wx(0)-4))
                    ctx.fillText(parseFloat(ly.toPrecision(3)), px2, wy(ly)+3)
                }

                // Curves — same evaluateRange() batched native call GraphTab
                // uses (see MathEngine.h), so this stays cheap even though
                // it repaints once per new AI message.
                for (var fi = 0; fi < root.expressions.length; fi++) {
                    ctx.strokeStyle = root.graphColors[fi % root.graphColors.length]
                    ctx.lineWidth = 2
                    ctx.lineJoin = "round"
                    ctx.beginPath()
                    var ys = mathEngine.evaluateRange(root.expressions[fi], root.xMin, root.xMax, W)
                    var inPath = false, prevFy = null
                    for (var px = 0; px <= W; px++) {
                        var fy = ys[px]
                        if (!isFinite(fy) || Math.abs(fy) > 1e8) { inPath = false; prevFy = null; continue }
                        if (prevFy !== null && Math.abs(fy - prevFy) > (root.yMax - root.yMin) * 3) inPath = false
                        if (!inPath) { ctx.moveTo(px, wy(fy)); inPath = true }
                        else         { ctx.lineTo(px, wy(fy)) }
                        prevFy = fy
                    }
                    ctx.stroke()
                }
            }
        }

        // Legend — small enough that a 2-4 expression list never wraps
        // past one row at typical chat-bubble width; long expressions
        // elide rather than pushing the row height around.
        Row {
            anchors.top: parent.top; anchors.left: parent.left
            anchors.margins: Theme.sp1
            anchors.right: parent.right
            spacing: Theme.sp2
            Repeater {
                model: root.expressions
                delegate: Row {
                    spacing: 3
                    Rectangle {
                        width: 7; height: 7; radius: 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.graphColors[index % root.graphColors.length]
                    }
                    Text {
                        text: modelData
                        color: Theme.textDim
                        font.family: Theme.fontMono
                        font.pixelSize: Math.round(9 * Theme.scale)
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
