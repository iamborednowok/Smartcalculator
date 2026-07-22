import QtQuick

// AmbientGlow v4 — soft diagonal RGB streaks behind the app chrome, in
// both light and dark mode (was dark-only in v1 — see REBUILD_NOTES.md
// "Light mode gets its own neon" for why: a near-white backdrop
// desaturates an overlaid translucent color much more than near-black
// does, so light mode needs a *higher* peak opacity than dark mode for
// comparable visible presence, not the same one — this was tuned by eye
// rather than derived from Theme.glowOp for that reason).
//
// v3: reference mood board shows many thin flowing strands per color
// (like a fiber-optic bundle), not a few wide soft bands — the original
// 4 streaks (one per color) read as soft blobs rather than that. 3
// thinner, slightly-offset strands per color (12 total) so each color
// reads as a small flowing bundle instead of a single wide stripe.
//
// v4: each strand now drifts slowly and independently (see driftPhase
// below) instead of sitting static — part of the app-wide "funky
// animation" pass, see REBUILD_NOTES.md.
//
// Deliberately built from plain Rectangle + Gradient only: CMakeLists.txt
// doesn't link Qt6::QuickEffects/GraphicalEffects, so a real Gaussian
// blur isn't available without adding a new module dependency this
// project hasn't opted into. Each strand fades to fully transparent at
// both ends (soft along its length); kept thin and at low opacity so the
// hard top/bottom edges read as light strands rather than a blurred
// blob, and so foreground text always stays legible.
Item {
    id: root
    anchors.fill: parent
    clip: true

    // One anchor point + angle per color "bundle"; 3 strands per bundle
    // fan out from slight position offsets so they read as flowing
    // together rather than as identical stacked copies.
    readonly property var bundleAnchors: [
        { px: 0.06, py: -0.06, ang: -27 },   // red    — upper-left
        { px: 0.88, py:  0.08, ang: -21 },   // green  — upper-right
        { px: -0.12, py: 0.54, ang: -31 },   // blue   — mid-left
        { px: 0.68, py:  0.82, ang: -19 },   // cyan   — lower-right
    ]
    readonly property var strandOffsets: [
        { dx: 0.000,  dy: 0.000,  dw: 0,   peakMul: 1.00 },
        { dx: 0.055,  dy: 0.045,  dw: -40, peakMul: 0.78 },
        { dx: -0.045, dy: -0.05,  dw: -70, peakMul: 0.62 },
    ]

    Repeater {
        model: 12   // 4 colors × 3 strands

        delegate: Rectangle {
            required property int index
            readonly property int bundleIdx: index % 4
            readonly property int strandIdx: Math.floor(index / 4)
            readonly property var bundle:  root.bundleAnchors[bundleIdx]
            readonly property var strand:  root.strandOffsets[strandIdx]
            readonly property color streakColor: Theme.bgStreakColors[bundleIdx]
            readonly property real  peak: (Theme.dark
                ? [0.18, 0.15, 0.16, 0.14][bundleIdx]
                : [0.24, 0.20, 0.22, 0.18][bundleIdx]) * strand.peakMul

            // Slow, gentle drift so the background reads as alive rather
            // than a static image — each strand desyncs from the others
            // (duration varies by bundle/strand index) so they drift
            // independently instead of visibly moving in lockstep, which
            // would read as mechanical rather than organic. Kept small
            // (a few px) and slow (7-11s per half-cycle) on purpose: this
            // sits behind every screen at all times, so "barely there" is
            // the target, not "eye-catching."
            property real driftPhase
            readonly property real driftPx: Math.round(12 * Theme.scale)
            readonly property int  driftMs: 7000 + bundleIdx * 900 + strandIdx * 1300
            // PERF FIX: these 12 strands used to animate unconditionally
            // forever, including while the app was backgrounded/minimized
            // — wasted CPU/battery for a decoration nobody could see.
            // Qt.application.state tracks foreground/background at the OS
            // level (Android included); gating `running` on it pauses the
            // animation timeline itself when backgrounded, not just its
            // on-screen result, and resumes from the same phase (no jump)
            // when foregrounded again.
            SequentialAnimation on driftPhase {
                running: Qt.application.state === Qt.ApplicationActive
                loops: Animation.Infinite
                NumberAnimation { from: 0.0; to: 1.0; duration: driftMs; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1.0; to: 0.0; duration: driftMs; easing.type: Easing.InOutSine }
            }

            width:  Math.round((460 + strand.dw) * Theme.scale)
            height: Math.round(34 * Theme.scale)
            x: root.width  * (bundle.px + strand.dx) - width  / 2 + (driftPhase - 0.5) * driftPx
            y: root.height * (bundle.py + strand.dy) - height / 2 + (driftPhase - 0.5) * driftPx * 0.6
            rotation: bundle.ang
            antialiasing: true

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0;  color: "transparent" }
                GradientStop { position: 0.5;  color: Theme.glowColor(streakColor, peak) }
                GradientStop { position: 1.0;  color: "transparent" }
            }
        }
    }
}
