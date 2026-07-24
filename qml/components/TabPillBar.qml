import QtQuick
import QtQuick.Layouts

// TabPillBar v2 — replaces TopRibbon + AppTabBar + MoreSheet with a single
// nav used in every orientation (see REBUILD_NOTES.md "Navigation" for why
// the wide/narrow split was retired in favor of one always-top pill row).
// Each tab gets its own identity color as a real 2-stop gradient
// (Theme.tabColors → tabColorsEnd), not a flat fill — matches the glassy
// gradient-pill look in the reference mood board. Active pill fills
// solid + glows, inactive pills stay quiet (colored icon, neutral label)
// so the row doesn't turn into noise.
Item {
    id: root

    property var  model:        []
    property int  currentIndex: 0
    property bool darkMode:     false

    signal tabClicked(int index)
    signal themeToggled()

    implicitHeight: Math.round(60 * Theme.scale)

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width; height: 1
        color: Theme.surface2
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin:  Theme.sp3
        anchors.rightMargin: Theme.sp3
        spacing: Theme.sp2

        Flickable {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            contentWidth:  pillRow.implicitWidth
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior:     Flickable.StopAtBounds
            clip: true

            Row {
                id: pillRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.sp2

                Repeater {
                    model: root.model
                    delegate: Item {
                        id: pill
                        readonly property bool  active: modelData.index === root.currentIndex
                        readonly property color homeColor:    Theme.tabColors[modelData.index % Theme.tabColors.length]
                        readonly property color homeColorEnd: Theme.tabColorsEnd[modelData.index % Theme.tabColorsEnd.length]
                        // FIX: light mode's active fill used to be a barely-
                        // there 16% tint (vs. dark mode's fully solid fill) —
                        // since the nav is on-screen at all times, that one
                        // gap alone made light mode read as washed-out next
                        // to dark mode. Near-solid in both now.
                        readonly property real fillOp: active ? (Theme.dark ? 1.0 : 0.90) : (Theme.dark ? 0.14 : 0.10)
                        readonly property color labelColor: active
                            ? Theme.textOnGradient(homeColor, homeColorEnd)
                            : Theme.textFaint
                        readonly property color iconColor: active ? labelColor : Theme.glowColor(homeColor, 0.85)

                        width:  content.implicitWidth + Theme.sp4
                        height: Math.round(38 * Theme.scale)

                        // Press bounce (quick down, springy back up — see
                        // Theme.bounceDuration/bounceEasing). Release always
                        // triggers the bounce-back (not just "became active"
                        // transitions) — otherwise tapping a pill that's
                        // already active would press down and never spring
                        // back up, since its `active` value never changes.
                        scale: 1.0
                        NumberAnimation {
                            id: pillPressDown
                            target: pill; property: "scale"; to: 0.90
                            duration: Theme.press; easing.type: Easing.OutQuad
                        }
                        NumberAnimation {
                            id: pillBounceBack
                            target: pill; property: "scale"; to: 1.0
                            duration: Theme.bounceDuration
                            easing.type: Theme.bounceEasing; easing.overshoot: Theme.bounceOvershoot
                        }

                        // Glow bloom behind the active pill (dark mode only)
                        Rectangle {
                            anchors.centerIn: parent
                            width:  parent.width  + Math.round(14 * Theme.scale)
                            height: parent.height + Math.round(14 * Theme.scale)
                            radius: Theme.rFull
                            color:  Theme.glowColor(pill.homeColor, Theme.glowOp)
                            visible: Theme.dark && pill.active
                        }

                        Rectangle {
                            id: face
                            anchors.fill: parent
                            radius: Theme.rFull
                            border.width: pill.active ? 0 : 1
                            border.color: Theme.glowColor(pill.homeColor, Theme.dark ? 0.35 : 0.25)
                            // Real 2-stop gradient per tab (base hue → an
                            // adjacent/lighter shade) instead of a flat fill —
                            // matches the glassy gradient-pill look in the
                            // reference mood board.
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop {
                                    position: 0.0; color: Theme.glowColor(pill.homeColor, pill.fillOp)
                                    Behavior on color { ColorAnimation { duration: Theme.normal } }
                                }
                                GradientStop {
                                    position: 1.0; color: Theme.glowColor(pill.homeColorEnd, pill.fillOp)
                                    Behavior on color { ColorAnimation { duration: Theme.normal } }
                                }
                            }
                        }

                        Row {
                            id: content
                            anchors.centerIn: parent
                            spacing: Theme.sp1

                            Text {
                                text: modelData.icon
                                font.pixelSize: Math.round(13 * Theme.scale)
                                color: pill.iconColor
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: Theme.normal } }
                            }
                            Text {
                                text: modelData.label
                                font.family: Theme.fontSans
                                font.weight: pill.active ? Font.DemiBold : Font.Medium
                                font.pixelSize: Math.round(12 * Theme.scale)
                                color: pill.labelColor
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: Theme.normal } }
                            }
                        }

                        TapHandler {
                            onPressedChanged: {
                                if (pressed) { pillBounceBack.stop(); pillPressDown.restart() }
                                else { pillPressDown.stop(); pillBounceBack.restart() }
                            }
                            onTapped: root.tabClicked(modelData.index)
                        }
                    }
                }
            }
        }

        // Theme toggle
        Item {
            Layout.preferredWidth: Math.round(36 * Theme.scale); Layout.preferredHeight: Layout.preferredWidth
            Text {
                anchors.centerIn: parent
                text: root.darkMode ? "☀" : "☾"
                font.pixelSize: Math.round(16 * Theme.scale)
                color: Theme.textDim
            }
            TapHandler { onTapped: root.themeToggled() }
        }
    }
}
