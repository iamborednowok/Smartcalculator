pragma Singleton
import QtQuick

// ───────────────────────────────────────────────────────────────────────
// SmartCalc design system — v4 ("RGB Neon")
//
// Color direction: red (#FF3B5C) + blue (#2F7BFF) as the two solid
// accents, with green (#1B9E5E) and cyan (#22D3EE) joining them as extra
// gradient stops so primary CTAs sweep red → green → blue — a real RGB
// gradient, not just a two-tone accent. Dark mode gets neon/glass touches
// via the glow system.
//
// ── How to re-color the whole app ────────────────────────────────────
// Edit the hex literals in the "Bold accents" and "Gradient" sections
// below. Every tab, button, and nav bar reads through these tokens —
// nothing is hardcoded elsewhere (except graphColors in GraphTab, the
// modal scrim black, and the graph color palette — see REBUILD_NOTES.md).
// ───────────────────────────────────────────────────────────────────────
QtObject {
    id: theme

    property bool dark:  false
    property real scale: 1.0

    // ── Neutrals ──────────────────────────────────────────────────────
    readonly property color bg:        dark ? "#0B0B0E" : "#FAFAF7"
    readonly property color surface:   dark ? "#18181C" : "#F0EEE9"
    readonly property color surface2:  dark ? "#22222A" : "#E8E4DC"

    // ── Text ──────────────────────────────────────────────────────────
    readonly property color text:      dark ? "#F5F5F2" : "#15151A"
    readonly property color textDim:   dark ? "#8A8890" : "#8C8A82"
    readonly property color textFaint: dark ? "#46454E" : "#CFCCC2"

    // ── Bold accents ── EDIT THESE TWO LINES TO RE-COLOR THE APP ──────
    readonly property color accent:   "#FF3B5C"   // red  — "=", primary CTAs, errors
    readonly property color accent2:  "#2F7BFF"   // blue — operators, ribbons
    readonly property color onAccent: "#FFFFFF"

    // ── Gradient trio (for buttons, headers, highlights) ──────────────
    // gradA/accent is red, gradB is green, gradC is cyan-blue — together
    // they sweep red → green → blue on every primary CTA (see CalcButton,
    // TopRibbon, and the "=" / Calculate / Add / Send buttons in each
    // tab). Two-stop pairings also read fine on their own: gradA→gradC
    // (Convert's swap button) or accent2→gradC (Random's roll/flip/pick).
    readonly property color gradA: "#FF3B5C"   // red start    (= accent)
    readonly property color gradB: "#1B9E5E"   // green        (gradient middle)
    readonly property color gradC: "#22D3EE"   // cyan-blue    (gradient end)

    // ── Glow system ───────────────────────────────────────────────────
    // glowOp is the master knob — set to 0 to kill every glow at once.
    // Dark mode: 0.30.  Light mode: 0 (no glow on warm whites).
    // Pre-baked RGBA colors so no component needs Qt.rgba() calls.
    // This drives *blurred bloom* effects specifically (an oversized,
    // soft-edged rect simulating light bleeding outward) — genuinely
    // dark-only, since the same trick against a light/white background
    // doesn't read as "glowing," it just reads as a smudge. See edgeOp
    // below for the crisp-border counterpart that isn't dark-only.
    readonly property real  glowOp:  dark ? 0.30 : 0.0
    readonly property color glowA:   Qt.rgba(1.00, 0.23, 0.36, glowOp)          // red bloom
    readonly property color glowA2:  Qt.rgba(1.00, 0.23, 0.36, glowOp * 0.45)  // softer red
    readonly property color glowB:   Qt.rgba(0.18, 0.48, 1.00, glowOp)          // blue bloom
    readonly property color glowB2:  Qt.rgba(0.18, 0.48, 1.00, glowOp * 0.45)  // softer blue

    // ── Edge system (crisp colored borders — the light-mode-compatible
    // counterpart to the glow blooms above) ─────────────────────────────
    // A thin *saturated line* reads as vivid/energetic on white the same
    // way it does on black, unlike a blur. Every card/button ring in the
    // app used to be wired to glowA/glowB directly, which made light mode
    // lose every one of them (glowOp is 0 there) — light mode ended up
    // with the same layout as dark mode but none of its personality. Same
    // opacity in both modes on purpose: the goal is for light and dark to
    // read as one consistent design system, not two.
    readonly property real  edgeOp:  0.42
    readonly property color edgeA:   Qt.rgba(1.00, 0.23, 0.36, edgeOp)
    readonly property color edgeA2:  Qt.rgba(1.00, 0.23, 0.36, edgeOp * 0.55)
    readonly property color edgeB:   Qt.rgba(0.18, 0.48, 1.00, edgeOp)
    readonly property color edgeB2:  Qt.rgba(0.18, 0.48, 1.00, edgeOp * 0.55)

    // ── Surface tints (accent-kissed card backgrounds) ─────────────────
    // Dark: perceptible but quiet.  Light: was barely-there before (near-
    // invisible warm/cool wash) — deepened so light mode cards actually
    // read as tinted instead of looking like plain Theme.surface.
    readonly property color surfaceEq: dark ? "#201014" : "#FFE0E6"   // red-tinted
    readonly property color surfaceOp: dark ? "#0F131F" : "#DCE9FF"   // blue-tinted

    // ── Per-tab identity colors ("RGB Neon" nav pills + bg glow) ───────
    // One vivid hue per tab, in allTabs order (Calc, Formula, Convert,
    // Random, Graph, Programmer, AI). Reuses accent/gradB/accent2/gradC
    // plus 3 more from the same family GraphTab's legend uses, so the
    // whole app pulls from one consistent set of hues rather than a
    // second, disconnected palette.
    readonly property var tabColors: [
        accent,    // Calc        — red
        gradB,     // Formula     — green
        accent2,   // Convert     — blue
        "#F4B740", // Random      — amber
        gradC,     // Graph       — cyan
        "#D63BA8", // Programmer  — magenta
        "#8B5CF6"  // AI          — violet
    ]
    // Paired end-stop per tab, same order — each nav pill is a real
    // 2-stop gradient (base hue → an adjacent/lighter shade), not a flat
    // fill, matching the glassy gradient-pill look in the reference
    // mood board. Reuses gradC/accent2 for Convert/Graph rather than
    // inventing yet another pair of hex values.
    readonly property var tabColorsEnd: [
        "#FF6F8F", // Calc        — lighter rose
        "#3ECE8A", // Formula     — lighter mint
        gradC,     // Convert     — cyan
        "#FFD873", // Random      — lighter gold
        accent2,   // Graph       — blue
        "#F06BC7", // Programmer  — lighter pink
        "#AB8CFF"  // AI          — lighter lavender
    ]
    // Same base hues, dimmed — used for the ambient background wash
    // (see Main.qml) so the streaks read as atmosphere, not UI.
    readonly property var bgStreakColors: [accent, gradB, accent2, gradC]

    // Turns any base color into a glow-ready rgba at a given opacity —
    // one function instead of a hand-derived glowX/glowX2 pair per hue,
    // so every tab color (and any future one) gets a matching glow for
    // free. Usage: Theme.glowColor(Theme.tabColors[i], Theme.glowOp)
    function glowColor(base, opacity) {
        return Qt.rgba(base.r, base.g, base.b, opacity)
    }

    // Picks readable text (near-black or white) for a given fill color.
    // Needed now that pills/badges can be filled with any of the 7 tab
    // colors, some of which (amber, cyan) are too light for white text.
    // Perceived-brightness heuristic (ITU-R BT.601 luma), not full WCAG
    // contrast math — good enough for a binary black-or-white choice.
    function textOn(fill) {
        var luma = 0.299 * fill.r + 0.587 * fill.g + 0.114 * fill.b
        return luma > 0.6 ? "#15151A" : "#FFFFFF"
    }
    // Same idea, but safe for a *gradient* fill spanning two colors —
    // checks whichever of the two stops is lighter (the harder case for
    // white text) so the chosen color stays readable across the whole
    // gradient, not just at one end of it.
    function textOnGradient(colorA, colorB) {
        var lumaA = 0.299 * colorA.r + 0.587 * colorA.g + 0.114 * colorA.b
        var lumaB = 0.299 * colorB.r + 0.587 * colorB.g + 0.114 * colorB.b
        return textOn(lumaA > lumaB ? colorA : colorB)
    }

    // ── Typography ────────────────────────────────────────────────────
    readonly property string fontSans: "DM Sans"
    readonly property string fontMono: "DM Mono"

    // ── Spacing scale ─────────────────────────────────────────────────
    readonly property int sp1: Math.round(4  * scale)
    readonly property int sp2: Math.round(8  * scale)
    readonly property int sp3: Math.round(14 * scale)
    readonly property int sp4: Math.round(22 * scale)
    readonly property int sp5: Math.round(34 * scale)
    readonly property int sp6: Math.round(52 * scale)

    // ── Radii ─────────────────────────────────────────────────────────
    readonly property int rSm:   Math.round(10 * scale)
    readonly property int rMd:   Math.round(18 * scale)
    readonly property int rLg:   Math.round(26 * scale)
    readonly property int rFull: 999

    // ── Motion ────────────────────────────────────────────────────────
    readonly property int press:  70
    readonly property int normal: 160

    // "Funky" bounce — a snappy press-down paired with a springy release
    // that overshoots slightly past its resting value before settling.
    // Used for anything satisfying to tap (CalcButton, hero gradient
    // buttons, nav pills, bit cells) instead of a flat linear settle.
    // Press itself stays quick/plain (Easing.OutQuad, `press` duration) —
    // the bounce is specifically on the way *back*, which is what reads
    // as playful without making the button feel laggy to actually use.
    readonly property int    bounceDuration:  380
    readonly property int    bounceEasing:    Easing.OutBack
    readonly property real   bounceOvershoot: 2.5
    // Same idea, slower/gentler — for content that enters the screen
    // (tab switches, a fresh result appearing) rather than a quick tap.
    readonly property int    popDuration:  320
    readonly property int    popEasing:    Easing.OutBack
    readonly property real   popOvershoot: 1.1

    // ── Navigation ────────────────────────────────────────────────────
    readonly property color navBg:       bg
    readonly property color navActive:   accent
    readonly property color navInactive: textFaint
}
