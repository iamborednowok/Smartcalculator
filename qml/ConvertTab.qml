import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "components"

Item {
    id: root
    property var window: ApplicationWindow.window

    // ── Clipboard helper ──────────────────────────────────────────────
    TextEdit { id: clipHelper; visible: false; text: "" }
    function copyToClipboard(t) { clipHelper.text = t; clipHelper.selectAll(); clipHelper.copy() }

    readonly property var unitCategories: ({
        "Length":      ["mm","cm","m","km","in","ft","yd","mi"],
        "Weight":      ["g","kg","lb","oz","t"],
        "Temperature": ["°C","°F","K"],
        "Speed":       ["m/s","km/h","mph"],
        "Volume":      ["ml","l","gal","cup"],
        "Time":        ["s","min","hr","day","wk","mo","yr"],
        "Data":        ["B","KB","MB","GB","TB"],
    })
    property var catNames: Object.keys(unitCategories)
    property int selectedCat: 0
    property string fromUnit: "m"
    property string toUnit:   "ft"
    property string inputVal: ""
    property string resultVal: ""

    function doConvert() {
        if (inputVal === "") { resultVal = ""; return }
        var n = parseFloat(inputVal)
        if (isNaN(n)) { resultVal = "Error"; return }
        var cat = catNames[selectedCat]
        var r = mathEngine.convertUnit(n, fromUnit, toUnit, cat)
        resultVal = mathEngine.formatNumber(r)
    }

    Flickable {
        anchors.fill: parent; anchors.margins: 14
        contentHeight: cvCol.implicitHeight + 20
        clip: true

        ColumnLayout {
            id: cvCol
            width: parent.width
            spacing: 12

            Text {
                text: "UNIT CONVERTER"
                font.pixelSize: Math.round(9 * Theme.scale); color: Theme.text3; font.letterSpacing: 1
            }

            // ── Category row ──────────────────────────────────────────
            Flickable {
                Layout.fillWidth: true; height: 32
                contentWidth: catRow.implicitWidth; clip: true
                Row {
                    id: catRow; spacing: 6
                    Repeater {
                        model: catNames
                        delegate: UnitPill {
                            label: modelData
                            active: selectedCat === index
                            onClicked: {
                                selectedCat = index
                                var units = unitCategories[catNames[index]]
                                fromUnit = units[0]
                                toUnit   = units.length > 1 ? units[1] : units[0]
                                inputVal = ""; resultVal = ""
                            }
                        }
                    }
                }
            }

            // ── From / Swap / To ──────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true; spacing: 8

                // From unit selector
                Rectangle {
                    Layout.fillWidth: true; height: 40; radius: 10
                    color: Theme.actionBg
                    border.color: Theme.border2; border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: fromUnit
                        color: Theme.accent2; font.pixelSize: Math.round(13 * Theme.scale); font.family: Theme.fontMono
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: fromUnitPopup.open()
                    }

                    Popup {
                        id: fromUnitPopup; modal: true; focus: true
                        contentItem: Column {
                            spacing: 0
                            Repeater {
                                model: unitCategories[catNames[selectedCat]]
                                delegate: Rectangle {
                                    width: 120; height: 36
                                    color: modelData === fromUnit ? Qt.rgba(0.42,0.36,0.91,0.12) : "transparent"
                                    Text { anchors.centerIn: parent; text: modelData
                                        color: Theme.text; font.pixelSize: Math.round(13 * Theme.scale) }
                                    MouseArea { anchors.fill: parent
                                        onClicked: { fromUnit = modelData; fromUnitPopup.close(); doConvert() }}
                                }
                            }
                        }
                    }
                }

                // Swap button
                Rectangle {
                    width: 38; height: 40; radius: 10
                    color: Theme.actionBg
                    border.color: Qt.rgba(1,1,1,0.12); border.width: 1
                    Text { anchors.centerIn: parent; text: "⇄"; color: "#a0a0c8"; font.pixelSize: Math.round(16 * Theme.scale) }
                    MouseArea { anchors.fill: parent
                        onClicked: { var tmp = fromUnit; fromUnit = toUnit; toUnit = tmp; doConvert() }
                    }
                }

                // To unit selector
                Rectangle {
                    Layout.fillWidth: true; height: 40; radius: 10
                    color: Theme.actionBg
                    border.color: Theme.border2; border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: toUnit
                        color: Theme.accent2; font.pixelSize: Math.round(13 * Theme.scale); font.family: Theme.fontMono
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: toUnitPopup.open()
                    }

                    Popup {
                        id: toUnitPopup; modal: true; focus: true
                        contentItem: Column {
                            spacing: 0
                            Repeater {
                                model: unitCategories[catNames[selectedCat]]
                                delegate: Rectangle {
                                    width: 120; height: 36
                                    color: modelData === toUnit ? Qt.rgba(0.42,0.36,0.91,0.12) : "transparent"
                                    Text { anchors.centerIn: parent; text: modelData
                                        color: Theme.text; font.pixelSize: Math.round(13 * Theme.scale) }
                                    MouseArea { anchors.fill: parent
                                        onClicked: { toUnit = modelData; toUnitPopup.close(); doConvert() }}
                                }
                            }
                        }
                    }
                }
            }

            // ── Input / Result ────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true; spacing: 12

                Column {
                    spacing: 5; Layout.fillWidth: true
                    Text { text: "FROM (" + fromUnit + ")"; font.pixelSize: Math.round(8 * Theme.scale); color: Theme.text3; font.letterSpacing: 0.8 }
                    StyledInput {
                        width: parent.width
                        placeholderText: "0"
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        onTextChanged: { inputVal = text; doConvert() }
                    }
                }

                Column {
                    spacing: 5; Layout.fillWidth: true
                    Text { text: "TO (" + toUnit + ")"; font.pixelSize: Math.round(8 * Theme.scale); color: Theme.text3; font.letterSpacing: 0.8 }
                    Rectangle {
                        width: parent.width; height: 42; radius: 10
                        color: Qt.rgba(0,0,0,0.30)
                        border.color: Qt.rgba(1,1,1,0.10); border.width: 1
                        Text {
                            anchors.fill: parent; anchors.margins: 12
                            verticalAlignment: Text.AlignVCenter
                            text: resultVal || "—"
                            color: Theme.accent2; font.pixelSize: Math.round(16 * Theme.scale); font.weight: Font.Light
                            font.family: Theme.fontMono
                        }
                    }
                }
            }

            // ── Action row ────────────────────────────────────────────
            RowLayout {
                visible: resultVal !== "" && resultVal !== "Error"
                spacing: 8

                Rectangle {
                    width: 50; height: 26; radius: 8
                    color: "transparent"; border.color: Theme.border2; border.width: 1
                    Text { anchors.centerIn: parent; text: "copy"; font.pixelSize: Math.round(9 * Theme.scale); color: "#60609a" }
                    MouseArea { anchors.fill: parent
                        onClicked: { copyToClipboard(resultVal + " " + toUnit); if(window) window.showToast("Copied!", true) } }
                }
                Rectangle {
                    width: 60; height: 26; radius: 8
                    color: "transparent"; border.color: Theme.border2; border.width: 1
                    Text { anchors.centerIn: parent; text: "→ Calc"; font.pixelSize: Math.round(9 * Theme.scale); color: "#60609a" }
                    MouseArea { anchors.fill: parent
                        onClicked: { if(window) window.currentTab = 0 } }
                }
            }
        }
    }
}
