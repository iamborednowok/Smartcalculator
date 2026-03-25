pragma Singleton
import QtQuick

QtObject {
    // ── Neon Noir Backgrounds ─────────────────────────────────────────
    readonly property color bg:        "#010208"
    readonly property color bg2:       "#04041a"
    readonly property color bg3:       "#07071e"

    // ── Liquid Glass layers ───────────────────────────────────────────
    readonly property color glass1:    Qt.rgba(1, 1, 1, 0.042)
    readonly property color glass2:    Qt.rgba(1, 1, 1, 0.075)
    readonly property color glass3:    Qt.rgba(1, 1, 1, 0.115)
    readonly property color glassBtn:  Qt.rgba(1, 1, 1, 0.065)

    // ── Glass borders ─────────────────────────────────────────────────
    readonly property color border1:   Qt.rgba(1, 1, 1, 0.08)
    readonly property color border2:   Qt.rgba(1, 1, 1, 0.14)
    readonly property color borderTop: Qt.rgba(1, 1, 1, 0.24)

    // ── Text hierarchy ────────────────────────────────────────────────
    readonly property color text:      "#f0f0ff"
    readonly property color text2:     "#8888cc"
    readonly property color text3:     "#44446a"

    // ── Neon accent spectrum ──────────────────────────────────────────
    readonly property color accent:     "#7C3AED"
    readonly property color accent2:    "#A78BFA"
    readonly property color accentSoft: "#9061FF"
    readonly property color accentGlow: Qt.rgba(0.49, 0.23, 0.93, 0.60)
    readonly property color accentDim:  Qt.rgba(0.49, 0.23, 0.93, 0.16)

    readonly property color cyan:       "#06B6D4"
    readonly property color cyanDim:    Qt.rgba(0.02, 0.71, 0.83, 0.15)
    readonly property color cyanGlow:   Qt.rgba(0.02, 0.71, 0.83, 0.45)

    // ── Status colors ─────────────────────────────────────────────────
    readonly property color green:     "#10B981"
    readonly property color red:       "#F43F5E"
    readonly property color yellow:    "#F59E0B"
    readonly property color blue:      "#3B82F6"

    // ── Glow palette ──────────────────────────────────────────────────
    readonly property color glowPurple: Qt.rgba(0.49, 0.23, 0.93, 0.40)
    readonly property color glowCyan:   Qt.rgba(0.02, 0.71, 0.83, 0.35)
    readonly property color glowGreen:  Qt.rgba(0.06, 0.73, 0.51, 0.32)
    readonly property color glowRed:    Qt.rgba(0.96, 0.25, 0.37, 0.32)

    readonly property color shadow1:   Qt.rgba(0, 0, 0, 0.65)
    readonly property color shadow2:   Qt.rgba(0, 0, 0, 0.85)

    // ── Typography ────────────────────────────────────────────────────
    readonly property string fontSans: "DM Sans"
    readonly property string fontMono: "DM Mono"
    readonly property string fontAlt:  "Space Grotesk"

    // ── Radii ─────────────────────────────────────────────────────────
    readonly property int r4:   4
    readonly property int r8:   8
    readonly property int r12: 12
    readonly property int r16: 16
    readonly property int r20: 20
    readonly property int r24: 24
    readonly property int r28: 28

    readonly property int fast:   65
    readonly property int normal: 150
    readonly property int slow:   260

    readonly property var graphColors: [
        "#8B5CF6","#06B6D4","#10B981","#F59E0B",
        "#F43F5E","#3B82F6","#EC4899","#84CC16"
    ]
}
