import QtQuick
import QtQuick.Layouts

// AppTabBar v79 — 4 primary tabs + "More" overflow button
// Primary:  CALC(0)  CONVERT(2)  GRAPH(4)  AI(6)
// More:     FORMULA(1)  RANDOM(3)  PROG(5)
Rectangle {
    id: root

    height: Math.round(68 * Theme.scale)
    Behavior on height { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }

    color: Theme.tabBg
    Behavior on color { ColorAnimation { duration: Theme.normal } }

    property int currentIndex: 0
    signal tabClicked(int index)
    signal moreClicked()

    readonly property bool isMoreActive: currentIndex === 1 || currentIndex === 3 || currentIndex === 5

    readonly property int pillSlot: {
        if (currentIndex === 0) return 0
        if (currentIndex === 2) return 1
        if (currentIndex === 4) return 2
        if (currentIndex === 6) return 3
        return 4
    }

    readonly property var primaryTabs: [
        { icon: "⊞",  label: "CALC",    tabIndex: 0 },
        { icon: "⇌",  label: "CONVERT", tabIndex: 2 },
        { icon: "↗",  label: "GRAPH",   tabIndex: 4 },
        { icon: "✦",  label: "AI",      tabIndex: 6 },
    ]

    // Top separator gradient
    Rectangle {
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

    readonly property real slotWidth: root.width / 5

    // Sliding active pill
    Rectangle {
        id: activePill
        y:      Math.round(6 * Theme.scale)
        height: root.height - Math.round(12 * Theme.scale)
        width:  root.slotWidth - Math.round(6 * Theme.scale)
        radius: Math.round(13 * Theme.scale)
        color:  Theme.tabPillBg
        Behavior on color { ColorAnimation { duration: Theme.normal } }
        border.color: Theme.tabPillBdr; border.width: 1
        Behavior on border.color { ColorAnimation { duration: Theme.normal } }

        Rectangle {
            anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.52; height: 1; y: 1; radius: 2
            color: Qt.rgba(1, 1, 1, 0.30)
        }

        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        function sync() { x = Math.round(3 * Theme.scale) + root.pillSlot * root.slotWidth }
        Component.onCompleted: sync()
    }

    onPillSlotChanged: activePill.sync()
    onWidthChanged:    Qt.callLater(activePill.sync)

    RowLayout {
        anchors.fill: parent; spacing: 0

        Repeater {
            model: root.primaryTabs
            delegate: Item {
                Layout.fillWidth: true; Layout.fillHeight: true
                readonly property bool isActive: root.currentIndex === modelData.tabIndex

                Column {
                    anchors.centerIn: parent
                    spacing: Math.round(2 * Theme.scale)

                    TabIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        label:        modelData.label
                        fallbackIcon: modelData.icon
                        isActive:     isActive
                        isMono:       false
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.label.substring(0, 4)
                        font.pixelSize: Math.round(6 * Theme.scale)
                        font.weight: Font.Bold
                        font.letterSpacing: 0.6
                        font.family: Theme.fontSans
                        color: isActive ? Theme.tabLblActive : Theme.tabLblInactive
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Math.round(3 * Theme.scale)
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.round(16 * Theme.scale); height: Math.round(2 * Theme.scale); radius: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Theme.accent }
                        GradientStop { position: 1.0; color: Theme.cyan   }
                    }
                    opacity: isActive ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                }

                MouseArea { anchors.fill: parent; onClicked: root.tabClicked(modelData.tabIndex) }
            }
        }

        // More button
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true

            Column {
                anchors.centerIn: parent
                spacing: Math.round(2 * Theme.scale)

                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width:  Math.round(28 * Theme.scale)
                    height: Math.round(24 * Theme.scale)

                    Row {
                        anchors.centerIn: parent
                        spacing: Math.round(3 * Theme.scale)
                        Repeater {
                            model: 3
                            delegate: Rectangle {
                                width: Math.round(4 * Theme.scale); height: width; radius: width / 2
                                color: root.isMoreActive ? Theme.tabLblActive : Theme.tabLblInactive
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }
                    }

                    Rectangle {
                        visible: root.isMoreActive
                        anchors.top: parent.top; anchors.right: parent.right
                        width: Math.round(7 * Theme.scale); height: width; radius: width / 2
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Theme.accent }
                            GradientStop { position: 1.0; color: Theme.cyan   }
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "MORE"
                    font.pixelSize: Math.round(6 * Theme.scale)
                    font.weight: Font.Bold
                    font.letterSpacing: 0.6
                    font.family: Theme.fontSans
                    color: root.isMoreActive ? Theme.tabLblActive : Theme.tabLblInactive
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Math.round(3 * Theme.scale)
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.round(16 * Theme.scale); height: Math.round(2 * Theme.scale); radius: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Theme.accent }
                    GradientStop { position: 1.0; color: Theme.cyan   }
                }
                opacity: root.isMoreActive ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 160 } }
            }

            MouseArea { anchors.fill: parent; onClicked: root.moreClicked() }
        }
    }
}
