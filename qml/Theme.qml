pragma Singleton
import QtQuick

QtObject {
    // Set from Main.qml
    property bool dark:  true
    // Auto-set by Main.qml based on actual window/screen dimensions.
    // All size-sensitive components multiply by this value so the UI
    // looks consistent on every screen density and window size.
    property real scale: 1.0

    // ── Backgrounds ───────────────────────────────────────────────────
    // Light: SVG sky palette   Dark: deep ocean void
    readonly property color bg:  dark ? "#060D14" : "#E9F5FC"
    readonly property color bg2: dark ? "#091826" : "#C8DFF0"

    // ── Surfaces (glass cards) ────────────────────────────────────────
    readonly property color glass1:   dark ? Qt.rgba(1,1,1,0.040) : Qt.rgba(1,1,1,0.72)
    readonly property color glassBtn: dark ? Qt.rgba(1,1,1,0.060) : Qt.rgba(1,1,1,0.82)

    // ── Borders ───────────────────────────────────────────────────────
    readonly property color border1:   dark ? Qt.rgba(1,1,1,0.07)         : Qt.rgba(1,1,1,0.88)
    readonly property color border2:   dark ? Qt.rgba(1,1,1,0.11)         : Qt.rgba(1,1,1,0.92)
    readonly property color borderTop: dark ? Qt.rgba(0,0.78,0.66,0.18)   : Qt.rgba(1,1,1,0.98)

    // ── Text hierarchy ────────────────────────────────────────────────
    readonly property color text:  dark ? "#DFF5F0" : "#0A2A45"
    readonly property color text2: dark ? "#7DCFBF" : "#1A6FB8"
    readonly property color text3: dark ? "#2A5E56" : "#6BACE0"

    // ── Accent ────────────────────────────────────────────────────────
    // Light: SVG blue  Dark: ocean teal
    readonly property color accent:    dark ? "#00C8A8" : "#1565C0"
    readonly property color accent2:   dark ? "#34D9BE" : "#5BAFF6"
    readonly property color accentDim: dark ? Qt.rgba(0,0.78,0.66,0.14) : Qt.rgba(0.08,0.40,0.75,0.14)

    // ── Cyan / sky ────────────────────────────────────────────────────
    readonly property color cyan:    dark ? "#00E5CC" : "#5BAFF6"
    readonly property color cyanDim: dark ? Qt.rgba(0,0.90,0.80,0.12) : Qt.rgba(0.36,0.69,0.96,0.22)

    // ── Button backgrounds ────────────────────────────────────────────
    readonly property color btnNormal: dark ? Qt.rgba(1,1,1,0.065)        : Qt.rgba(1,1,1,0.80)
    readonly property color btnOp:     dark ? Qt.rgba(0,0.78,0.66,0.18)   : Qt.rgba(0.36,0.69,0.96,0.28)
    readonly property color btnRed:    dark ? Qt.rgba(0.98,0.27,0.35,0.10): Qt.rgba(0.83,0.19,0.19,0.10)
    readonly property color btnSci:    dark ? Qt.rgba(0,0.78,0.66,0.08)   : Qt.rgba(0.36,0.69,0.96,0.18)
    readonly property color btnDim:    dark ? Qt.rgba(1,1,1,0.040)        : Qt.rgba(1,1,1,0.65)

    // ── Button borders ────────────────────────────────────────────────
    readonly property color bdrNormal: dark ? Qt.rgba(1,1,1,0.08)          : Qt.rgba(1,1,1,0.88)
    readonly property color bdrOp:     dark ? Qt.rgba(0,0.78,0.66,0.38)    : Qt.rgba(0.36,0.69,0.96,0.55)
    readonly property color bdrEq:     dark ? Qt.rgba(0,0.78,0.66,0.40)    : Qt.rgba(0.08,0.40,0.75,0.45)
    readonly property color bdrRed:    dark ? Qt.rgba(0.98,0.27,0.35,0.35) : Qt.rgba(0.83,0.19,0.19,0.30)
    readonly property color bdrSci:    dark ? Qt.rgba(0,0.78,0.66,0.28)    : Qt.rgba(0.36,0.69,0.96,0.50)
    readonly property color bdrDim:    dark ? Qt.rgba(1,1,1,0.06)          : Qt.rgba(1,1,1,0.78)

    // ── Equals button gradient ────────────────────────────────────────
    // Light: deep-to-sky blue sweep   Dark: teal sweep
    readonly property color eqA: dark ? "#00524A" : "#1565C0"
    readonly property color eqB: dark ? "#007E6C" : "#1E88E5"
    readonly property color eqC: dark ? "#00C8A8" : "#5BAFF6"

    // ── Button label colours ──────────────────────────────────────────
    readonly property color lblNormal: dark ? "#DFF5F0" : "#0A2A45"
    readonly property color lblOp:     dark ? "#34D9BE" : "#1A6FB8"
    readonly property color lblEq:     "#ffffff"
    readonly property color lblRed:    dark ? "#FF7088" : "#C62828"
    readonly property color lblSci:    dark ? "#00E5CC" : "#1565C0"
    readonly property color lblDim:    dark ? "#7DCFBF" : "#1A6FB8"

    // ── Status ────────────────────────────────────────────────────────
    readonly property color green:  dark ? "#10E896" : "#10B981"
    readonly property color red:    dark ? "#FF4865" : "#F43F5E"
    readonly property color yellow: dark ? "#FFB020" : "#F59E0B"
    readonly property color blue:   dark ? "#38C8F0" : "#3B82F6"

    // ── Tab bar ───────────────────────────────────────────────────────
    readonly property color tabBg:          dark ? Qt.rgba(0.02,0.05,0.08,0.97) : Qt.rgba(0.91,0.96,0.99,0.97)
    readonly property color tabActive:      dark ? "#00C8A8" : "#1565C0"
    readonly property color tabInactive:    dark ? "#1A3530"  : "#A8CDE8"
    readonly property color tabLblActive:   dark ? "#34D9BE" : "#1565C0"
    readonly property color tabLblInactive: dark ? "#1A3530"  : "#A8CDE8"
    readonly property color tabPillBg:      dark ? Qt.rgba(0,0.78,0.66,0.14)  : Qt.rgba(0.36,0.69,0.96,0.16)
    readonly property color tabPillBdr:     dark ? Qt.rgba(0,0.78,0.66,0.30)  : Qt.rgba(0.36,0.69,0.96,0.45)
    readonly property color tabSep0:        dark ? Qt.rgba(0,0.78,0.66,0.30)  : Qt.rgba(0.36,0.69,0.96,0.35)
    readonly property color tabSep1:        dark ? Qt.rgba(0,0.90,0.80,0.20)  : Qt.rgba(0.08,0.40,0.75,0.25)

    // ── Display card ──────────────────────────────────────────────────
    readonly property color displayBg:  dark ? Qt.rgba(1,1,1,0.042) : Qt.rgba(1,1,1,0.75)
    readonly property color displayBdr: dark ? Qt.rgba(1,1,1,0.08)  : Qt.rgba(1,1,1,0.90)

    // ── Toast ─────────────────────────────────────────────────────────
    readonly property color toastBg0: dark ? Qt.rgba(0.02,0.05,0.08,0.97) : Qt.rgba(0.91,0.96,0.99,0.97)
    readonly property color toastBg1: dark ? Qt.rgba(0.04,0.09,0.15,0.97) : Qt.rgba(0.82,0.92,0.98,0.97)

    // ── Section cards ─────────────────────────────────────────────────
    readonly property color sectionBg:  dark ? Qt.rgba(0,0,0,0.20)  : Qt.rgba(1,1,1,0.55)
    readonly property color sectionBdr: dark ? Qt.rgba(1,1,1,0.07)  : Qt.rgba(1,1,1,0.75)

    // ── UnitPill ──────────────────────────────────────────────────────
    readonly property color pillActiveBg:    dark ? Qt.rgba(0,0.78,0.66,0.18) : Qt.rgba(0.36,0.69,0.96,0.20)
    readonly property color pillActiveBdr:   dark ? Qt.rgba(0,0.78,0.66,0.42) : Qt.rgba(0.36,0.69,0.96,0.55)
    readonly property color pillInactiveBg:  dark ? Qt.rgba(1,1,1,0.04)       : Qt.rgba(1,1,1,0.65)
    readonly property color pillInactiveBdr: dark ? Qt.rgba(1,1,1,0.08)       : Qt.rgba(1,1,1,0.78)
    readonly property color pillActiveLbl:   dark ? "#34D9BE" : "#1565C0"
    readonly property color pillInactiveLbl: dark ? "#2A5E56"  : "#A8CDE8"

    // ── StyledInput ───────────────────────────────────────────────────
    readonly property color inputBg:          dark ? Qt.rgba(1,1,1,0.05)       : Qt.rgba(1,1,1,0.72)
    readonly property color inputBdr:         dark ? Qt.rgba(1,1,1,0.09)       : Qt.rgba(1,1,1,0.80)
    readonly property color inputFocusBdr:    dark ? Qt.rgba(0,0.78,0.66,0.60) : Qt.rgba(0.36,0.69,0.96,0.65)
    readonly property color inputText:        dark ? "#DFF5F0" : "#0A2A45"
    readonly property color inputPlaceholder: dark ? "#2A5E56"  : "#9BCDE8"

    // ── Utility header / action pill ──────────────────────────────────
    readonly property color actionBg:    dark ? Qt.rgba(1,1,1,0.05) : Qt.rgba(1,1,1,0.65)
    readonly property color actionBdr:   dark ? Qt.rgba(1,1,1,0.09) : Qt.rgba(1,1,1,0.78)
    readonly property color actionLabel: dark ? "#2A5E56" : "#9BCDE8"

    // ── Typography ────────────────────────────────────────────────────
    readonly property string fontSans: "DM Sans"
    readonly property string fontMono: "DM Mono"

    // ── Radii ─────────────────────────────────────────────────────────
    readonly property int r8:  8;  readonly property int r12: 12
    readonly property int r16: 16; readonly property int r18: 18
    readonly property int r20: 20; readonly property int r24: 24

    // ── Timings ───────────────────────────────────────────────────────
    readonly property int fast:    65
    readonly property int normal:  150
    readonly property int slow:    260
    readonly property int press:    65
    readonly property int release: 260

    // ── Graph colors ──────────────────────────────────────────────────
    readonly property var graphColors: dark
        ? ["#00C8A8","#38C8F0","#FFB020","#FF4865","#A07DFF","#34D9BE","#FF88AA","#A8E860"]
        : ["#1565C0","#5BAFF6","#10B981","#F59E0B","#F43F5E","#3B82F6","#EC4899","#84CC16"]
}
