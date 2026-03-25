import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    height: 72

    // Floating frosted bottom bar
    color: Qt.rgba(0.02, 0.02, 0.10, 0.94)

    property int  currentIndex: 0
    signal tabClicked(int index)

    readonly property var tabs: [
        { icon: "⊞",  label: "CALC"    },
        { icon: "∑",  label: "FORMULA" },
        { icon: "⇌",  label: "CONVERT" },
        { icon: "🎲", label: "RANDOM"  },
        { icon: "📈", label: "GRAPH"   },
        { icon: "✦",  label: "AI"      },
    ]

    // ── Top separator line with gradient fade ─────────────────────────
    Rectangle {
        width: parent.width; height: 1
        anchors.top: parent.top
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.00; color: "transparent" }
            GradientStop { position: 0.15; color: Qt.rgba(0.49, 0.23, 0.93, 0.40) }
            GradientStop { position: 0.50; color: Qt.rgba(0.49, 0.23, 0.93, 0.60) }
            GradientStop { position: 0.85; color: Qt.rgba(0.02, 0.71, 0.83, 0.40) }
            GradientStop { position: 1.00; color: "transparent" }
        }
    }

    // ── Sliding active pill ───────────────────────────────────────────
    Rectangle {
        id: activePill
        y: 10
        height: 52
        width:  root.width / root.tabs.length - 8
        radius: 18

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(0.49, 0.23, 0.93, 0.22) }
            GradientStop { position: 1.0; color: Qt.rgba(0.02, 0.71, 0.83, 0.14) }
        }

        border.color: Qt.rgba(0.67, 0.55, 1.0, 0.30)
        border.width: 1

        // Pill top sheen
        Rectangle {
            anchors.top:  parent.top; anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.55; height: 1; y: 1; radius: 2
            color: Qt.rgba(1, 1, 1, 0.28)
        }

        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Component.onCompleted: x = 4 + root.currentIndex * (root.width / root.tabs.length)
        onParentChanged:       x = 4 + root.currentIndex * (root.width / root.tabs.length)
    }

    onCurrentIndexChanged: {
        activePill.x = 4 + currentIndex * (width / tabs.length)
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Repeater {
            model: root.tabs

            delegate: Item {
                Layout.fillWidth:  true
                Layout.fillHeight: true

                readonly property bool isActive: root.currentIndex === index

                Column {
                    anchors.centerIn: parent
                    spacing: 3

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.icon
                        font.pixelSize: 17
                        color: isActive ? "#C4B5FD" : "#353560"
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.label
                        font.pixelSize: 7
                        font.weight: Font.Bold
                        font.letterSpacing: 0.9
                        font.family: "DM Sans"
                        color: isActive ? "#A78BFA" : "#2e2e55"
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                // Cyan dot indicator under active tab
                Rectangle {
                    visible: isActive
                    anchors.bottom:           parent.bottom
                    anchors.bottomMargin:     5
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 16; height: 2; radius: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#7C3AED" }
                        GradientStop { position: 1.0; color: "#06B6D4" }
                    }
                    opacity: isActive ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    // Soft glow
                    Rectangle {
                        anchors.centerIn: parent
                        width: 28; height: 6; radius: 3
                        color: Qt.rgba(0.49, 0.23, 0.93, 0.22)
                        z: -1
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.tabClicked(index)
                }
            }
        }
    }
}
