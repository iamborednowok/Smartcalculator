import QtQuick
import QtQuick.Layouts

// MoreSheet — slides DOWN from below the header when toggled.
// BUG FIX: Old implementation had a complex visible binding that caused
// the sheet to flash open on startup (sheetPanel.height starts at 0,
// making the initial y = -10 which passed the > -(h+9) guard while
// the Behavior animated from 0 → -10, blocking all tab taps).
// NEW: use opacity-gated visibility + z-ordering so it never blocks taps.
Item {
    id: root

    property int  currentIndex: 0
    property int  topOffset:    52
    signal tabClicked(int index)

    // isOpen is the ONLY source of truth for visibility
    property bool isOpen: false

    // Scrim opacity animates independently — leads the sheet on open,
    // trails it on close — for a smoother layered feel.
    property real scrimOpacity: 0.0
    onIsOpenChanged: {
        if (isOpen) {
            scrimFadeOut.stop()   // prevent competing fade-out from overriding
            scrimFadeIn.restart()
        } else {
            scrimFadeIn.stop()    // prevent competing fade-in from overriding
            scrimFadeOut.restart()
        }
    }
    NumberAnimation { id: scrimFadeIn;  target: root; property: "scrimOpacity"; to: 1.0; duration: 160; easing.type: Easing.OutQuad }
    NumberAnimation { id: scrimFadeOut; target: root; property: "scrimOpacity"; to: 0.0; duration: 320; easing.type: Easing.InQuad }

    function open()   { isOpen = true  }
    function close()  { isOpen = false }
    function toggle() { isOpen = !isOpen }

    readonly property var moreTabs: [
        { icon: "∑",  label: "FORMULA", sub: "Equations",  tabIndex: 1 },
        { icon: "🎲", label: "RANDOM",  sub: "Generators", tabIndex: 3 },
        { icon: "01", label: "PROG",    sub: "Bit / Hex",  tabIndex: 5 },
    ]

    // Only render the overlay when open (or animating out via opacity)
    // z: 50 keeps this above tab content but we never expand below tab bar
    z: 50
    // The item itself always fills parent but only intercepts events when open
    visible: true

    // ── Dim overlay ───────────────────────────────────────────────────
    // The MoreSheet parent is anchored to stop at the tab bar in Main.qml
    Item {
        id: dimOverlay
        anchors.top:    parent.top
        anchors.topMargin: root.topOffset
        anchors.left:   parent.left
        anchors.right:  parent.right
        // Stop just above the bottom edge so we don't cover the tab bar
        anchors.bottom: parent.bottom

        opacity: root.scrimOpacity
        // No Behavior needed — scrimOpacity has its own NumberAnimations above

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.45)
        }

        MouseArea {
            anchors.fill: parent
            // Only consume events when fully open; lets taps pass through while animating out
            enabled: root.isOpen
            onClicked: root.close()
        }
    }

    // ── Sheet panel ───────────────────────────────────────────────────
    Rectangle {
        id: sheetPanel

        width:  parent.width
        anchors.top:       parent.top
        anchors.topMargin: root.topOffset

        // Height driven by content
        height: sheetInner.implicitHeight + Math.round(48 * Theme.scale)
        clip: true

        // Only round bottom corners
        radius: Math.round(22 * Theme.scale)
        Rectangle {
            anchors.top:  parent.top
            width: parent.width
            height: Math.round(22 * Theme.scale)
            color: parent.color
        }

        // FIX: solid background — no transparency so content never bleeds through
        color: Theme.tabBg
        Behavior on color { ColorAnimation { duration: Theme.normal } }

        // Top border line
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left:   parent.left
            anchors.right:  parent.right
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.2; color: Theme.tabSep0 }
                GradientStop { position: 0.8; color: Theme.tabSep1 }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // Bottom drag handle
        Rectangle {
            anchors.bottom:           parent.bottom
            anchors.bottomMargin:     Math.round(12 * Theme.scale)
            anchors.horizontalCenter: parent.horizontalCenter
            width:  Math.round(44 * Theme.scale)
            height: Math.round(4  * Theme.scale)
            radius: 2
            color:  Qt.rgba(0.5, 0.6, 0.7, 0.35)
        }

        // Drop shadow line
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left:   parent.left
            anchors.right:  parent.right
            height: 1
            color: Qt.rgba(0.5, 0.6, 0.75, 0.25)
        }

        // ── Slide animation ───────────────────────────────────────────
        // FIX: use y-offset on the panel itself, NOT a Transform.
        // Start at -height (hidden above header), slide to 0 (visible).
        // The panel is always in the DOM — no height-calculation race.
        y: root.isOpen ? 0 : -sheetPanel.height
        Behavior on y {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }

        // ── Content ───────────────────────────────────────────────────
        Column {
            id: sheetInner
            anchors {
                left:  parent.left
                right: parent.right
                top:   parent.top
                margins: Math.round(16 * Theme.scale)
                topMargin: Math.round(18 * Theme.scale)
            }
            spacing: Math.round(14 * Theme.scale)

            // Section header
            Text {
                text: "MORE TOOLS"
                font.pixelSize:    Math.round(9  * Theme.scale)
                font.weight:       Font.Bold
                font.letterSpacing: 1.8
                font.family: Theme.fontSans
                color: Theme.text3
                leftPadding: Math.round(2 * Theme.scale)
            }

            // Three tool cards in a row
            RowLayout {
                width: parent.width
                spacing: Math.round(10 * Theme.scale)

                Repeater {
                    model: root.moreTabs
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        height: Math.round(88 * Theme.scale)
                        radius: Math.round(16 * Theme.scale)

                        readonly property bool isActive: root.currentIndex === modelData.tabIndex

                        color: isActive
                            ? Theme.tabPillBg
                            : (Theme.dark ? Qt.rgba(1,1,1,0.04) : Qt.rgba(0.93,0.97,1.0,1.0))
                        border.color: isActive ? Theme.tabPillBdr
                            : (Theme.dark ? Qt.rgba(1,1,1,0.09) : Qt.rgba(0.6,0.75,0.9,0.45))
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 160 } }

                        // Active top bar
                        Rectangle {
                            visible: isActive
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width * 0.50
                            height: Math.round(3 * Theme.scale)
                            radius: 2
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Theme.accent }
                                GradientStop { position: 1.0; color: Theme.cyan   }
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: Math.round(6 * Theme.scale)

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.icon
                                font.pixelSize: Math.round(22 * Theme.scale)
                                color: isActive ? Theme.tabLblActive : Theme.tabLblInactive
                                Behavior on color { ColorAnimation { duration: 160 } }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                                font.pixelSize:    Math.round(9 * Theme.scale)
                                font.weight:       Font.Bold
                                font.letterSpacing: 0.8
                                font.family: Theme.fontSans
                                color: isActive ? Theme.tabLblActive : Theme.tabLblInactive
                                Behavior on color { ColorAnimation { duration: 160 } }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.sub
                                font.pixelSize: Math.round(8 * Theme.scale)
                                font.family:    Theme.fontSans
                                color: isActive ? Theme.accent2 : Theme.text3
                                Behavior on color { ColorAnimation { duration: 160 } }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.tabClicked(modelData.tabIndex)
                                root.close()
                            }
                        }
                    }
                }
            }
        }
    }
}
