import QtQuick

// GroupTabs v2 — ribbon-style group selector with glowing active underline.
// Model: array of strings  OR  [{label, value}] objects.
// Usage:
//   GroupTabs {
//       model: [{label:"DEC",value:"dec"}, ...]
//       currentValue: root.base
//       onSelected: function(v) { root.base = v }
//   }
Flickable {
    id: root

    property var model:        []
    property var currentValue: null
    signal selected(var value)

    implicitHeight: row.implicitHeight
    contentWidth:   row.implicitWidth
    contentHeight:  implicitHeight
    flickableDirection: Flickable.HorizontalFlick
    boundsBehavior:     Flickable.StopAtBounds
    clip: true

    Row {
        id: row
        spacing: Theme.sp5

        Repeater {
            model: root.model
            delegate: Column {
                id: item
                readonly property var    itemVal:   (modelData.value !== undefined) ? modelData.value : modelData
                readonly property string itemLabel: (modelData.label !== undefined) ? modelData.label : String(modelData)
                readonly property bool   active:    item.itemVal === root.currentValue
                spacing: Theme.sp1

                Text {
                    id: lbl
                    text: item.itemLabel
                    font.family: Theme.fontSans
                    font.weight: item.active ? Font.DemiBold : Font.Normal
                    font.pixelSize: Math.round(13 * Theme.scale)
                    color: item.active ? Theme.text : Theme.textDim
                    Behavior on color { ColorAnimation { duration: Theme.normal } }
                }

                // Active underline + glow bloom below it
                Item {
                    width: lbl.implicitWidth
                    height: Math.round(4 * Theme.scale)

                    // Glow bloom (dark mode only — wider, softer, behind the line)
                    Rectangle {
                        anchors.centerIn: parent
                        width:  lbl.implicitWidth + Math.round(10 * Theme.scale)
                        height: Math.round(8 * Theme.scale)
                        radius: 4
                        color:  item.active ? Theme.glowB : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.normal } }
                    }

                    // Crisp underline
                    Rectangle {
                        anchors.centerIn: parent
                        width:  lbl.implicitWidth
                        height: Math.round(2 * Theme.scale)
                        radius: 1
                        color: item.active ? Theme.accent2 : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.normal } }
                    }
                }

                TapHandler { onTapped: root.selected(item.itemVal) }
            }
        }
    }
}
