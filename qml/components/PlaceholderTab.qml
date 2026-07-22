import QtQuick

// PlaceholderTab — temporary stand-in for tabs not yet rebuilt.
// Will be replaced with the redesigned screen in a later pass.
Item {
    property string tabName: "Tab"

    Column {
        anchors.centerIn: parent
        spacing: Theme.sp2
        width: parent.width * 0.7

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tabName
            font.family: Theme.fontSans
            font.weight: Font.DemiBold
            font.pixelSize: Math.round(20 * Theme.scale)
            color: Theme.text
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Redesign coming in the next pass"
            font.family: Theme.fontSans
            font.pixelSize: Math.round(13 * Theme.scale)
            color: Theme.textDim
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            width: parent.width
        }
    }
}
