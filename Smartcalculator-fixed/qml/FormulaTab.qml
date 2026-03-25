import QtQuick
import QtQuick.Layouts
import "components"

Item {
    id: root
    property var window: ApplicationWindow.window

    // ── Formula data ──────────────────────────────────────────────────
    readonly property var formulaData: ({
        "Geometry": [
            { name:"Circle Area",     icon:"⬤", color:"#60b8f0", expr:"A = π × r²",       unit:"units²",
              vars:[{k:"r",label:"Radius",hint:"e.g. 5"}],
              fn: function(v){ return Math.PI * v.r * v.r } },
            { name:"Circumference",   icon:"◯", color:"#60b8f0", expr:"C = 2π × r",        unit:"units",
              vars:[{k:"r",label:"Radius",hint:"e.g. 5"}],
              fn: function(v){ return 2 * Math.PI * v.r } },
            { name:"Rectangle Area",  icon:"▬", color:"#60d090", expr:"A = l × w",          unit:"units²",
              vars:[{k:"l",label:"Length",hint:"e.g. 8"},{k:"w",label:"Width",hint:"e.g. 4"}],
              fn: function(v){ return v.l * v.w } },
            { name:"Triangle Area",   icon:"△", color:"#e0c060", expr:"A = ½ × b × h",     unit:"units²",
              vars:[{k:"b",label:"Base",hint:"e.g. 6"},{k:"h",label:"Height",hint:"e.g. 4"}],
              fn: function(v){ return 0.5 * v.b * v.h } },
            { name:"Pythagorean c",   icon:"📐",color:"#e0c060", expr:"c = √(a²+b²)",       unit:"units",
              vars:[{k:"a",label:"Side a",hint:"e.g. 3"},{k:"b",label:"Side b",hint:"e.g. 4"}],
              fn: function(v){ return Math.sqrt(v.a*v.a + v.b*v.b) } },
            { name:"Sphere Volume",   icon:"🔵",color:"#a080e8", expr:"V = ⁴⁄₃π × r³",    unit:"units³",
              vars:[{k:"r",label:"Radius",hint:"e.g. 3"}],
              fn: function(v){ return 4/3 * Math.PI * Math.pow(v.r,3) } },
            { name:"Cylinder Volume", icon:"🧱",color:"#80c8a0", expr:"V = π × r² × h",    unit:"units³",
              vars:[{k:"r",label:"Radius",hint:"e.g. 3"},{k:"h",label:"Height",hint:"e.g. 5"}],
              fn: function(v){ return Math.PI * v.r*v.r * v.h } },
        ],
        "Finance": [
            { name:"Compound Interest",icon:"📈",color:"#70d890",expr:"A = P(1+r/n)^(nt)",  unit:"$",
              vars:[{k:"P",label:"Principal",hint:"1000"},{k:"r",label:"Annual rate",hint:"0.07"},
                    {k:"n",label:"Times/year",hint:"12"},{k:"t",label:"Years",hint:"10"}],
              fn: function(v){ return v.P * Math.pow(1+v.r/v.n, v.n*v.t) } },
            { name:"Simple Interest",  icon:"💵",color:"#70d890",expr:"I = P × r × t",       unit:"$",
              vars:[{k:"P",label:"Principal",hint:"1000"},{k:"r",label:"Rate",hint:"0.05"},{k:"t",label:"Years",hint:"3"}],
              fn: function(v){ return v.P * v.r * v.t } },
            { name:"Mortgage Payment", icon:"🏠",color:"#f0a060",expr:"M = Pr(1+r)ⁿ/((1+r)ⁿ-1)",unit:"$/mo",
              vars:[{k:"P",label:"Loan",hint:"300000"},{k:"r",label:"Monthly rate",hint:"0.005"},{k:"n",label:"Months",hint:"360"}],
              fn: function(v){ return v.P*v.r*Math.pow(1+v.r,v.n)/(Math.pow(1+v.r,v.n)-1) } },
            { name:"ROI",              icon:"💹",color:"#70d890",expr:"(gain-cost)/cost×100",  unit:"%",
              vars:[{k:"gain",label:"Final value",hint:"15000"},{k:"cost",label:"Cost",hint:"10000"}],
              fn: function(v){ return (v.gain-v.cost)/v.cost*100 } },
            { name:"Tip Calculator",   icon:"🍽",color:"#f0d060",expr:"tip = bill × tip%/100",unit:"$",
              vars:[{k:"bill",label:"Bill amount",hint:"84.50"},{k:"tip",label:"Tip %",hint:"15"}],
              fn: function(v){ return v.bill * v.tip / 100 } },
        ],
        "Physics": [
            { name:"Kinetic Energy",   icon:"⚡",color:"#f0e060",expr:"KE = ½ × m × v²",    unit:"J",
              vars:[{k:"m",label:"Mass (kg)",hint:"5"},{k:"v",label:"Velocity (m/s)",hint:"10"}],
              fn: function(v){ return 0.5 * v.m * v.v * v.v } },
            { name:"Force F=ma",       icon:"🎯",color:"#f09060",expr:"F = m × a",            unit:"N",
              vars:[{k:"m",label:"Mass (kg)",hint:"5"},{k:"a",label:"Accel (m/s²)",hint:"9.8"}],
              fn: function(v){ return v.m * v.a } },
            { name:"Ohm's Law V=IR",   icon:"🔌",color:"#60c8f0",expr:"V = I × R",            unit:"V",
              vars:[{k:"I",label:"Current (A)",hint:"2"},{k:"R",label:"Resistance (Ω)",hint:"50"}],
              fn: function(v){ return v.I * v.R } },
            { name:"Power P=IV",       icon:"💡",color:"#f0e060",expr:"P = I × V",            unit:"W",
              vars:[{k:"I",label:"Current (A)",hint:"2"},{k:"V",label:"Voltage (V)",hint:"120"}],
              fn: function(v){ return v.I * v.V } },
        ]
    })

    property var categories: Object.keys(formulaData)
    property int selectedCat: 0
    property var selectedFormula: null
    property var varValues: ({})
    property string result: ""
    property string resultUnit: ""

    function calcFormula() {
        if (!selectedFormula) return
        var vals = {}
        for (var i = 0; i < selectedFormula.vars.length; i++) {
            var k = selectedFormula.vars[i].k
            var n = parseFloat(varValues[k] || "")
            if (isNaN(n)) { result = "Fill all fields"; resultUnit = ""; return }
            vals[k] = n
        }
        try {
            var r = selectedFormula.fn(vals)
            result = mathEngine.formatNumber(r)
            resultUnit = selectedFormula.unit
            if (window) window.addHistory(selectedFormula.name, result + " " + resultUnit)
        } catch(e) { result = "Error"; resultUnit = "" }
    }

    // ── UI ────────────────────────────────────────────────────────────
    Flickable {
        anchors.fill: parent
        anchors.margins: 14
        contentHeight: fmCol.implicitHeight + 20
        clip: true

        ColumnLayout {
            id: fmCol
            width: parent.width
            spacing: 10

            // Back button when a formula is selected
            RowLayout {
                visible: selectedFormula !== null
                Layout.fillWidth: true

                Rectangle {
                    width: 70; height: 28; radius: 8
                    color: Qt.rgba(1,1,1,0.06)
                    border.color: Qt.rgba(1,1,1,0.12); border.width: 1
                    Text { anchors.centerIn: parent; text: "← back"
                        font.pixelSize: 11; color: "#a0a0c8" }
                    MouseArea { anchors.fill: parent
                        onClicked: { selectedFormula = null; varValues = {}; result = ""; resultUnit = "" } }
                }

                Text {
                    visible: selectedFormula !== null
                    text: selectedFormula ? (selectedFormula.icon + " " + selectedFormula.name) : ""
                    color: window ? window.textColor : "#f0f0ff"
                    font.pixelSize: 14; font.weight: Font.Medium
                    leftPadding: 8
                }
            }

            // ── Category tabs ─────────────────────────────────────────
            Row {
                visible: selectedFormula === null
                spacing: 6
                Repeater {
                    model: categories
                    delegate: UnitPill {
                        label: modelData
                        active: selectedCat === index
                        onClicked: { selectedCat = index; selectedFormula = null; result = "" }
                    }
                }
            }

            // ── Formula list ──────────────────────────────────────────
            Repeater {
                visible: selectedFormula === null
                model: selectedFormula === null ? formulaData[categories[selectedCat]] : []
                delegate: Rectangle {
                    Layout.fillWidth: true
                    height: 56; radius: 12
                    color: Qt.rgba(1,1,1,0.06)
                    border.color: Qt.rgba(1,1,1,0.09); border.width: 1

                    RowLayout {
                        anchors.fill: parent; anchors.margins: 12; spacing: 10

                        Rectangle { width: 3; height: 36; radius: 1.5; color: modelData.color }

                        Column {
                            spacing: 2; Layout.fillWidth: true
                            RowLayout {
                                spacing: 8
                                Text { text: modelData.name; color: "#d0d0f8"; font.pixelSize: 12 }
                                Text { text: modelData.expr; color: modelData.color; font.pixelSize: 10; opacity: 0.8 }
                            }
                        }

                        Text { text: modelData.icon; font.pixelSize: 18; color: "#383860" }
                    }

                    scale: ma.pressed ? 0.97 : 1.0
                    Behavior on scale { NumberAnimation { duration: 70 } }

                    MouseArea {
                        id: ma; anchors.fill: parent
                        onClicked: { selectedFormula = modelData; varValues = {}; result = ""; resultUnit = "" }
                    }
                }
            }

            // ── Formula detail ────────────────────────────────────────
            // Formula box
            Rectangle {
                visible: selectedFormula !== null
                Layout.fillWidth: true; height: 56; radius: 12
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(0.42,0.36,0.91,0.10) }
                    GradientStop { position: 1.0; color: Qt.rgba(0.31,0.20,0.82,0.05) }
                }
                border.color: selectedFormula ? selectedFormula.color + "40" : "transparent"; border.width: 1
                leftBorder.color: selectedFormula ? selectedFormula.color : "transparent"; leftBorder.width: 3

                Column {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 14; spacing: 2
                    Text { text: "FORMULA"; font.pixelSize: 8; color: "#8080b8"; font.letterSpacing: 1 }
                    Text {
                        text: selectedFormula ? selectedFormula.expr : ""
                        color: selectedFormula ? selectedFormula.color : "transparent"
                        font.pixelSize: 14; font.family: "serif"
                    }
                }
            }

            // Variable inputs
            Repeater {
                visible: selectedFormula !== null
                model: selectedFormula ? selectedFormula.vars : []
                delegate: RowLayout {
                    Layout.fillWidth: true; spacing: 10

                    Column {
                        spacing: 2; Layout.preferredWidth: parent.width * 0.40
                        Text { text: modelData.label; color: "#9090c0"; font.pixelSize: 11 }
                        Text { text: modelData.hint;  color: "#7070a0"; font.pixelSize: 9 }
                    }

                    StyledInput {
                        Layout.fillWidth: true
                        placeholderText: modelData.hint
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        onTextChanged: {
                            var updated = Object.assign({}, varValues)
                            updated[modelData.k] = text
                            varValues = updated
                            result = ""
                        }
                    }
                }
            }

            // Calculate button
            Rectangle {
                visible: selectedFormula !== null
                Layout.fillWidth: true; height: 44; radius: 12
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#5b50f2" }
                    GradientStop { position: 1.0; color: "#7c3aed" }
                }
                Text { anchors.centerIn: parent; text: "Calculate"; color: "#fff"
                    font.pixelSize: 13; font.weight: Font.DemiBold }
                scale: calcMa.pressed ? 0.97 : 1.0
                Behavior on scale { NumberAnimation { duration: 60 } }
                MouseArea { id: calcMa; anchors.fill: parent; onClicked: calcFormula() }
            }

            // Result box
            Rectangle {
                visible: result !== ""
                Layout.fillWidth: true; height: 80; radius: 12
                color: Qt.rgba(0,0,0,0.25)
                border.color: selectedFormula ? selectedFormula.color + "30" : "transparent"; border.width: 1

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 14; spacing: 4
                    Text { text: "RESULT"; font.pixelSize: 8; color: "#6060a0"; font.letterSpacing: 1 }
                    RowLayout {
                        Text { text: result; color: "#f4f4ff"; font.pixelSize: 24; font.weight: Font.Light }
                        Text { text: resultUnit; color: "#8080a8"; font.pixelSize: 12; leftPadding: 4 }
                        Item { Layout.fillWidth: true }
                    }
                    RowLayout {
                        spacing: 8
                        Rectangle {
                            width: 50; height: 22; radius: 7
                            color: "transparent"; border.color: Qt.rgba(1,1,1,0.14); border.width: 1
                            Text { anchors.centerIn: parent; text: "copy"; font.pixelSize: 9; color: "#60609a" }
                            MouseArea { anchors.fill: parent
                                onClicked: { if(window) window.showToast("Copied!", true) } }
                        }
                        Rectangle {
                            width: 60; height: 22; radius: 7
                            color: "transparent"; border.color: Qt.rgba(1,1,1,0.14); border.width: 1
                            Text { anchors.centerIn: parent; text: "→ Calc"; font.pixelSize: 9; color: "#60609a" }
                            MouseArea { anchors.fill: parent
                                onClicked: {
                                    if (window) {
                                        window.currentTab = 0
                                        window.showToast("Sent to calculator")
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item { height: 10 }
        }
    }
}
