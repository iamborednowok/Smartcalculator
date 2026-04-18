import QtQuick
import QtQuick.Layouts

// MoreSheet v79 — slide-up bottom sheet for overflow tabs
// Shows FORMULA(1), RANDOM(3), PROG(5)
Item {
    id: root

    property int currentIndex: 0
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

    // Guard: only intercept the item tree (and run animations) when needed.
    // sheetPanel.height isn't stable at construction, so compare against a
    // threshold instead of root.height to avoid a binding that fires too early.
    visible: root.isOpen || sheetSlide.y < (sheetPanel.height + 10)

    // Dim overlay
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.50)
        opacity: root.isOpen ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        // Disable hit-testing when invisible so taps reach content behind the sheet
        MouseArea { anchors.fill: parent; enabled: root.isOpen; onClicked: root.close() }
    }

    // Sheet panel
    Rectangle {
        id: sheetPanel
        width:  parent.width
        anchors.bottom: parent.bottom

        height: sheetInner.implicitHeight + Math.round(24 * Theme.scale)

        radius: Math.round(22 * Theme.scale)
        // Bottom corners flat
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width; height: Math.round(22 * Theme.scale)
            color: parent.color
        }

        color: Theme.tabBg
        border.color: Qt.rgba(1, 1, 1, 0.09); border.width: 1

        transform: Translate {
            id: sheetSlide
            y: root.isOpen ? 0 : sheetPanel.height + 10
            Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        }

        // Handle bar
        Rectangle {
            anchors.top:              parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            y:      Math.round(10 * Theme.scale)
            width:  Math.round(40 * Theme.scale)
            height: Math.round(4  * Theme.scale)
            radius: 2
            color:  Qt.rgba(1, 1, 1, 0.20)
        }

        // Top separator line
        Rectangle {
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
            height: 1; y: 0
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
            anchors.topMargin: Math.round(26 * Theme.scale)
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

                        // Inner top sheen when active
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
                            anchors.topMargin: 0
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
                                color: isActive ? Qt.rgba(0.4,0.9,0.8,0.8) : Theme.text3
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
