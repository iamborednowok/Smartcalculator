import QtQuick
import QtQuick.Layouts

// MoreSheet — dropdown from the top header button
// Slides DOWN from below the header (instead of up from the bottom).
// Shows FORMULA(1), RANDOM(3), PROG(5)
Item {
    id: root

    property int currentIndex: 0
    property int topOffset:    52    // Set from Main.qml to match appHeader.height
    signal tabClicked(int index)

    property bool isOpen: false

    function open()   { isOpen = true  }
    function close()  { isOpen = false }
    function toggle() { isOpen = !isOpen }

    readonly property var moreTabs: [
        { icon: "∑",  label: "FORMULA", sub: "Equations",  tabIndex: 1 },
        { icon: "🎲", label: "RANDOM",  sub: "Generators", tabIndex: 3 },
        { icon: "01", label: "PROG",    sub: "Bit / Hex",  tabIndex: 5 },
    ]

    // Visible while open or while the panel is still animating out
    visible: root.isOpen || sheetSlide.y > -(sheetPanel.height + 9)

    // Dim overlay — covers the content area below the header
    Item {
        anchors.top:       parent.top
        anchors.topMargin: root.topOffset
        anchors.left:      parent.left
        anchors.right:     parent.right
        anchors.bottom:    parent.bottom

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.52)
            opacity: root.isOpen ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        }
        // Tap outside to close
        MouseArea {
            anchors.fill: parent
            enabled: root.isOpen
            onClicked: root.close()
        }
    }

    // Sheet panel — slides down from below the header
    Rectangle {
        id: sheetPanel
        width:  parent.width
        anchors.top:       parent.top
        anchors.topMargin: root.topOffset

        height: sheetInner.implicitHeight + Math.round(32 * Theme.scale)

        // Only round the bottom corners
        radius: Math.round(22 * Theme.scale)
        Rectangle {
            anchors.top: parent.top
            width: parent.width; height: Math.round(22 * Theme.scale)
            color: parent.color
        }

        color: Theme.tabBg
        border.color: Qt.rgba(1, 1, 1, 0.09); border.width: 1
        Behavior on color { ColorAnimation { duration: Theme.normal } }

        // Slide transform: closed = fully above the anchor, open = at anchor
        transform: Translate {
            id: sheetSlide
            y: root.isOpen ? 0 : -(sheetPanel.height + 10)
            Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        }

        // Bottom handle bar
        Rectangle {
            anchors.bottom:           parent.bottom
            anchors.bottomMargin:     Math.round(10 * Theme.scale)
            anchors.horizontalCenter: parent.horizontalCenter
            width:  Math.round(40 * Theme.scale)
            height: Math.round(4  * Theme.scale)
            radius: 2
            color:  Qt.rgba(1, 1, 1, 0.20)
        }

        // Bottom separator line
        Rectangle {
            anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.2; color: Theme.tabSep0 }
                GradientStop { position: 0.8; color: Theme.tabSep1 }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        Column {
            id: sheetInner
            anchors {
                left: parent.left; right: parent.right
                top:  parent.top
                margins: Math.round(16 * Theme.scale)
            }
            anchors.topMargin: Math.round(16 * Theme.scale)
            spacing: Math.round(12 * Theme.scale)

            Text {
                text: "MORE TOOLS"
                font.pixelSize: Math.round(9  * Theme.scale)
                font.weight:    Font.Bold
                font.letterSpacing: 1.8
                font.family: Theme.fontSans
                color: Theme.text3
                leftPadding: Math.round(2 * Theme.scale)
            }

            RowLayout {
                width: parent.width
                spacing: Math.round(10 * Theme.scale)

                Repeater {
                    model: root.moreTabs
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        height: Math.round(80 * Theme.scale)
                        radius: Math.round(18 * Theme.scale)

                        readonly property bool isActive: root.currentIndex === modelData.tabIndex

                        color: isActive ? Theme.tabPillBg : Qt.rgba(1, 1, 1, 0.04)
                        border.color: isActive ? Theme.tabPillBdr : Qt.rgba(1, 1, 1, 0.09)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 160 } }

                        // Top sheen when active
                        Rectangle {
                            visible: isActive
                            anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width * 0.55; height: 1; y: 1; radius: 2
                            color: Qt.rgba(1, 1, 1, 0.28)
                        }

                        // Active gradient bar at top
                        Rectangle {
                            visible: isActive
                            anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width * 0.50; height: Math.round(2 * Theme.scale); radius: 1
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Theme.accent }
                                GradientStop { position: 1.0; color: Theme.cyan   }
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: Math.round(5 * Theme.scale)

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.icon
                                font.pixelSize: Math.round(24 * Theme.scale)
                                color: isActive ? Theme.tabLblActive : Theme.tabLblInactive
                                Behavior on color { ColorAnimation { duration: 160 } }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                                font.pixelSize: Math.round(9  * Theme.scale)
                                font.weight: Font.Bold
                                font.letterSpacing: 0.8
                                font.family: Theme.fontSans
                                color: isActive ? Theme.tabLblActive : Theme.tabLblInactive
                                Behavior on color { ColorAnimation { duration: 160 } }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.sub
                                font.pixelSize: Math.round(8  * Theme.scale)
                                font.family: Theme.fontSans
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
