import QtQuick
import QtQuick.Layouts

// AppTabBar — redesigned for clarity and reliable touch targets.
// Primary tabs: CALC(0)  CONVERT(2)  GRAPH(4)  AI(6)
// "More" button (⋯) opens MoreSheet which shows FORMULA/RANDOM/PROG.
Rectangle {
    id: root

    // Increased height for comfortable touch targets on all device sizes
    height: Math.round(64 * Theme.scale)
    Behavior on height { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }

    // FIX: Solid, fully opaque background — no bleed-through in light mode
    color: Theme.tabBg
    Behavior on color { ColorAnimation { duration: Theme.normal } }

    property int currentIndex: 0
    signal tabClicked(int index)

    // Is any "More" sub-tab active?
    readonly property bool isMoreActive: currentIndex === 1 || currentIndex === 3 || currentIndex === 5

    // Which pill slot (0-3) should the indicator sit in? -1 = "More" is active
    readonly property int pillSlot: {
        if (currentIndex === 0) return 0
        if (currentIndex === 2) return 1
        if (currentIndex === 4) return 2
        if (currentIndex === 6) return 3
        return -1  // "More" sub-tab — pill hides, More button lights up
    }

    readonly property var primaryTabs: [
        { icon: "⊞", label: "CALC",    tabIndex: 0 },
        { icon: "⇌", label: "CONVERT", tabIndex: 2 },
        { icon: "↗", label: "GRAPH",   tabIndex: 4 },
        { icon: "✦", label: "AI",      tabIndex: 6 },
    ]

    // Top separator
    Rectangle {
        id: topSep
        width: parent.width; height: 1; anchors.top: parent.top
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.00; color: "transparent" }
            GradientStop { position: 0.15; color: Theme.tabSep0 }
            GradientStop { position: 0.50; color: Theme.tabSep0 }
            GradientStop { position: 0.85; color: Theme.tabSep1 }
            GradientStop { position: 1.00; color: "transparent" }
        }
    }

    // ── Sliding active pill ───────────────────────────────────────────
    // Sits behind the tab icons so it never blocks taps
    readonly property real slotW: root.width / 5  // 4 primary + 1 more

    Rectangle {
        id: activePill
        z: 0
        y:      Math.round(7 * Theme.scale)
        height: root.height - Math.round(14 * Theme.scale)
        width:  root.slotW - Math.round(8 * Theme.scale)
        radius: Math.round(14 * Theme.scale)
        color:  Theme.tabPillBg
        Behavior on color { ColorAnimation { duration: Theme.normal } }
        border.color: Theme.tabPillBdr; border.width: 1
        Behavior on border.color { ColorAnimation { duration: Theme.normal } }

        // Glass sheen line on top
        Rectangle {
            anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.50; height: 1; y: 1; radius: 2
            color: Qt.rgba(1, 1, 1, Theme.dark ? 0.28 : 0.70)
        }

        opacity: root.pillSlot >= 0 ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180 } }

        Behavior on x { NumberAnimation { duration: 230; easing.type: Easing.OutCubic } }

        function sync() {
            if (root.pillSlot >= 0)
                x = Math.round(4 * Theme.scale) + root.pillSlot * root.slotW
        }
        Component.onCompleted: sync()
    }

    onPillSlotChanged: activePill.sync()
    onWidthChanged:    Qt.callLater(activePill.sync)

    // ── Tab items ─────────────────────────────────────────────────────
    RowLayout {
        anchors.fill: parent
        spacing: 0
        z: 1  // Above the pill so taps always register

        // Four primary tabs
        Repeater {
            model: root.primaryTabs
            delegate: Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                readonly property bool isActive: root.currentIndex === modelData.tabIndex

                Column {
                    anchors.centerIn: parent
                    spacing: Math.round(3 * Theme.scale)

                    // Icon
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.icon
                        font.pixelSize: Math.round(18 * Theme.scale)
                        color: isActive ? Theme.tabLblActive : Theme.tabLblInactive
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    // Label
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.label
                        font.pixelSize:     Math.round(8 * Theme.scale)
                        font.weight:        Font.Bold
                        font.letterSpacing: 0.5
                        font.family:        Theme.fontSans
                        color: isActive ? Theme.tabLblActive : Theme.tabLblInactive
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                // Active dot indicator at bottom
                Rectangle {
                    anchors.bottom:           parent.bottom
                    anchors.bottomMargin:     Math.round(4 * Theme.scale)
                    anchors.horizontalCenter: parent.horizontalCenter
                    width:  Math.round(18 * Theme.scale)
                    height: Math.round(3  * Theme.scale)
                    radius: 2
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Theme.accent }
                        GradientStop { position: 1.0; color: Theme.cyan   }
                    }
                    opacity: isActive ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                }

                // Tap target — full cell, always on top
                MouseArea {
                    anchors.fill: parent
                    z: 10
                    onClicked: root.tabClicked(modelData.tabIndex)
                }
            }
        }

        // ── "More" button ─────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            readonly property bool isActive: root.isMoreActive

            Column {
                anchors.centerIn: parent
                spacing: Math.round(3 * Theme.scale)

                // Three-dot icon
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Math.round(4 * Theme.scale)
                    Repeater {
                        model: 3
                        Rectangle {
                            width:  Math.round(5 * Theme.scale)
                            height: width
                            radius: width / 2
                            color: parent.parent.parent.isActive
                                ? Theme.tabLblActive : Theme.tabLblInactive
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "MORE"
                    font.pixelSize:     Math.round(8 * Theme.scale)
                    font.weight:        Font.Bold
                    font.letterSpacing: 0.5
                    font.family:        Theme.fontSans
                    color: parent.parent.isActive ? Theme.tabLblActive : Theme.tabLblInactive
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            // Active indicator dot
            Rectangle {
                anchors.bottom:           parent.bottom
                anchors.bottomMargin:     Math.round(4 * Theme.scale)
                anchors.horizontalCenter: parent.horizontalCenter
                width:  Math.round(18 * Theme.scale)
                height: Math.round(3  * Theme.scale)
                radius: 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Theme.accent }
                    GradientStop { position: 1.0; color: Theme.cyan   }
                }
                opacity: parent.isActive ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 160 } }
            }

            // Notification badge when a "More" sub-tab is active
            Rectangle {
                visible: root.isMoreActive
                anchors {
                    top:        parent.top
                    horizontalCenter: parent.horizontalCenter
                    topMargin:  Math.round(6 * Theme.scale)
                    horizontalCenterOffset: Math.round(14 * Theme.scale)
                }
                width: Math.round(8 * Theme.scale)
                height: width
                radius: width / 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Theme.accent }
                    GradientStop { position: 1.0; color: Theme.cyan   }
                }
            }

            MouseArea {
                anchors.fill: parent
                z: 10
                // This tab routes through Main.qml's MoreSheet toggle
                // We emit a special index (-1) that Main handles
                onClicked: root.tabClicked(-1)
            }
        }
    }
}
