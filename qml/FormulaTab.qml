import QtQuick
import QtQuick.Layouts
import "components"

Item {
    id: root
    property var window: ApplicationWindow.window

    // ── Entrance animation (plays each time this tab becomes current) ──
    // A quick fade + gentle pop-in on switching to this tab instead of
    // just snapping into view — see Theme.popDuration/popEasing.
    opacity: 1.0
    scale: 1.0
    // Driven from Main.qml — see GraphTab.qml for why this is no longer
    // StackLayout.isCurrentItem (this tab is now lazy-loaded via Loader).
    property bool isCurrentTab: false
    onIsCurrentTabChanged: if (isCurrentTab) { enterFade.restart(); enterScale.restart() }
    NumberAnimation { id: enterFade;  target: root; property: "opacity"; from: 0.0;  to: 1.0; duration: Theme.popDuration; easing.type: Easing.OutQuad }
    NumberAnimation { id: enterScale; target: root; property: "scale";   from: 0.97; to: 1.0; duration: Theme.popDuration; easing.type: Theme.popEasing; easing.overshoot: Theme.popOvershoot }

    // ── Formula data (logic unchanged — only per-item "color" field dropped;
    // icon + name now differentiate rows instead of a rainbow accent) ──────
    readonly property var formulaData: ({
        "Geometry": [
            { name:"Circle Area",     icon:"⬤",  expr:"A = π × r²",            unit:"units²",
              vars:[{k:"r",label:"Radius",hint:"e.g. 5"}],
              fn: function(v){ return Math.PI * v.r * v.r } },
            { name:"Circumference",   icon:"◯",  expr:"C = 2π × r",             unit:"units",
              vars:[{k:"r",label:"Radius",hint:"e.g. 5"}],
              fn: function(v){ return 2 * Math.PI * v.r } },
            { name:"Rectangle Area",  icon:"▬",  expr:"A = l × w",              unit:"units²",
              vars:[{k:"l",label:"Length",hint:"e.g. 8"},{k:"w",label:"Width",hint:"e.g. 4"}],
              fn: function(v){ return v.l * v.w } },
            { name:"Triangle Area",   icon:"△",  expr:"A = ½ × b × h",          unit:"units²",
              vars:[{k:"b",label:"Base",hint:"e.g. 6"},{k:"h",label:"Height",hint:"e.g. 4"}],
              fn: function(v){ return 0.5 * v.b * v.h } },
            { name:"Pythagorean c",   icon:"📐", expr:"c = √(a²+b²)",           unit:"units",
              vars:[{k:"a",label:"Side a",hint:"e.g. 3"},{k:"b",label:"Side b",hint:"e.g. 4"}],
              fn: function(v){ return Math.sqrt(v.a*v.a + v.b*v.b) } },
            { name:"Sphere Volume",   icon:"🔵", expr:"V = ⁴⁄₃π × r³",          unit:"units³",
              vars:[{k:"r",label:"Radius",hint:"e.g. 3"}],
              fn: function(v){ return 4/3 * Math.PI * Math.pow(v.r,3) } },
            { name:"Cylinder Volume", icon:"🧱", expr:"V = π × r² × h",         unit:"units³",
              vars:[{k:"r",label:"Radius",hint:"e.g. 3"},{k:"h",label:"Height",hint:"e.g. 5"}],
              fn: function(v){ return Math.PI * v.r*v.r * v.h } },
        ],
        "Finance": [
            { name:"Compound Interest",icon:"📈", expr:"A = P(1+r/n)^(nt)",    unit:"$",
              vars:[{k:"P",label:"Principal",hint:"1000"},{k:"r",label:"Annual rate",hint:"0.07"},
                    {k:"n",label:"Times/year",hint:"12"},{k:"t",label:"Years",hint:"10"}],
              fn: function(v){ return v.P * Math.pow(1+v.r/v.n, v.n*v.t) } },
            { name:"Simple Interest",  icon:"💵", expr:"I = P × r × t",         unit:"$",
              vars:[{k:"P",label:"Principal",hint:"1000"},{k:"r",label:"Rate",hint:"0.05"},{k:"t",label:"Years",hint:"3"}],
              fn: function(v){ return v.P * v.r * v.t } },
            { name:"Mortgage Payment", icon:"🏠", expr:"M = Pr(1+r)ⁿ/((1+r)ⁿ-1)",unit:"$/mo",
              vars:[{k:"P",label:"Loan",hint:"300000"},{k:"r",label:"Monthly rate",hint:"0.005"},{k:"n",label:"Months",hint:"360"}],
              fn: function(v){ return v.P*v.r*Math.pow(1+v.r,v.n)/(Math.pow(1+v.r,v.n)-1) } },
            { name:"ROI",              icon:"💹", expr:"(gain-cost)/cost×100",  unit:"%",
              vars:[{k:"gain",label:"Final value",hint:"15000"},{k:"cost",label:"Cost",hint:"10000"}],
              fn: function(v){ return (v.gain-v.cost)/v.cost*100 } },
            { name:"Tip Calculator",   icon:"🍽", expr:"tip = bill × tip%/100",unit:"$",
              vars:[{k:"bill",label:"Bill amount",hint:"84.50"},{k:"tip",label:"Tip %",hint:"15"}],
              fn: function(v){ return v.bill * v.tip / 100 } },
        ],
        "Physics": [
            { name:"Kinetic Energy",   icon:"⚡", expr:"KE = ½ × m × v²",       unit:"J",
              vars:[{k:"m",label:"Mass (kg)",hint:"5"},{k:"v",label:"Velocity (m/s)",hint:"10"}],
              fn: function(v){ return 0.5 * v.m * v.v * v.v } },
            { name:"Force F=ma",       icon:"🎯", expr:"F = m × a",             unit:"N",
              vars:[{k:"m",label:"Mass (kg)",hint:"5"},{k:"a",label:"Accel (m/s²)",hint:"9.8"}],
              fn: function(v){ return v.m * v.a } },
            { name:"Ohm's Law V=IR",   icon:"🔌", expr:"V = I × R",             unit:"V",
              vars:[{k:"I",label:"Current (A)",hint:"2"},{k:"R",label:"Resistance (Ω)",hint:"50"}],
              fn: function(v){ return v.I * v.R } },
            { name:"Power P=IV",       icon:"💡", expr:"P = I × V",             unit:"W",
              vars:[{k:"I",label:"Current (A)",hint:"2"},{k:"V",label:"Voltage (V)",hint:"120"}],
              fn: function(v){ return v.I * v.V } },
        ]
    })

    readonly property var categories: Object.keys(formulaData)
    property string category: categories[0]
    property var    selectedFormula: null
    property var    varValues: ({})
    property string result: ""
    property string resultUnit: ""

    function openFormula(f) { selectedFormula = f; varValues = {}; result = ""; resultUnit = "" }
    function back() { selectedFormula = null; varValues = {}; result = ""; resultUnit = "" }

    // ── Clipboard ─────────────────────────────────────────────────────
    // BUG FIX: the "copy" row used to just show a "Copied" toast without
    // ever touching the clipboard. Wired up to the same hidden-TextEdit
    // pattern CalcTab/ConvertTab already use.
    TextEdit { id: clipHelper; visible: false; text: "" }
    function copyResult() {
        if (result === "") return
        clipHelper.text = result + (resultUnit ? " " + resultUnit : "")
        clipHelper.selectAll()
        clipHelper.copy()
        if (window) window.showToast("Copied", true)
    }

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

    Flickable {
        anchors.fill: parent
        anchors.margins: Theme.sp4
        contentHeight: col.implicitHeight
        clip: true

        ColumnLayout {
            id: col
            width: parent.width
            spacing: Theme.sp4

            // ── List view ───────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.selectedFormula === null
                spacing: Theme.sp4

                GroupTabs {
                    Layout.fillWidth: true
                    model: root.categories
                    currentValue: root.category
                    onSelected: function(v) { root.category = v }
                }

                Repeater {
                    model: root.formulaData[root.category]
                    delegate: Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round(52 * Theme.scale)

                        RowLayout {
                            anchors.fill: parent
                            spacing: Theme.sp3
                            Text { text: modelData.icon; font.pixelSize: Math.round(18 * Theme.scale) }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { text: modelData.name; color: Theme.text; font.family: Theme.fontSans; font.weight: Font.Medium; font.pixelSize: Math.round(14 * Theme.scale) }
                                Text { text: modelData.expr; color: Theme.textDim; font.family: Theme.fontMono; font.pixelSize: Math.round(11 * Theme.scale) }
                            }
                            Text { text: "›"; color: Theme.textFaint; font.pixelSize: Math.round(16 * Theme.scale) }
                        }
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.surface2 }
                        TapHandler { onTapped: root.openFormula(modelData) }
                    }
                }
            }

            // ── Detail view ─────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.selectedFormula !== null
                spacing: Theme.sp4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.sp3
                    Text {
                        text: "‹ back"
                        color: Theme.accent2
                        font.family: Theme.fontSans
                        font.weight: Font.Medium
                        font.pixelSize: Math.round(13 * Theme.scale)
                        TapHandler { onTapped: root.back() }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.selectedFormula ? (root.selectedFormula.icon + "  " + root.selectedFormula.name) : ""
                        color: Theme.text
                        font.family: Theme.fontSans
                        font.weight: Font.DemiBold
                        font.pixelSize: Math.round(15 * Theme.scale)
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: Math.round(52 * Theme.scale)
                    radius: Theme.rMd
                    color: Theme.surface
                    Text {
                        anchors.centerIn: parent
                        text: root.selectedFormula ? root.selectedFormula.expr : ""
                        color: Theme.accent2
                        font.family: Theme.fontMono
                        font.pixelSize: Math.round(15 * Theme.scale)
                    }
                }

                Repeater {
                    model: root.selectedFormula ? root.selectedFormula.vars : []
                    delegate: ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.sp1
                        Text { text: modelData.label; color: Theme.textDim; font.family: Theme.fontSans; font.pixelSize: Math.round(12 * Theme.scale) }
                        StyledInput {
                            Layout.fillWidth: true
                            placeholderText: modelData.hint
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                            onTextChanged: {
                                var updated = Object.assign({}, root.varValues)
                                updated[modelData.k] = text
                                root.varValues = updated
                                root.result = ""
                            }
                        }
                    }
                }

                Rectangle {
                    id: calcBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(48 * Theme.scale)
                    radius: Theme.rMd
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Theme.gradA }
                        GradientStop { position: 0.5; color: Theme.gradB }
                        GradientStop { position: 1.0; color: Theme.gradC }
                    }
                    // Glow ring (both modes — see Theme.edgeA)
                    Rectangle {
                        anchors.fill: parent; anchors.margins: -2
                        radius: parent.radius + 2
                        color: "transparent"
                        border.width: 2; border.color: Theme.edgeA
                    }
                    Text { anchors.centerIn: parent; text: "Calculate"; color: Theme.textOnAccent; font.family: Theme.fontSans; font.weight: Font.DemiBold; font.pixelSize: Math.round(14 * Theme.scale) }

                    // Funky press bounce (quick down, springy back up — see
                    // Theme.bounceDuration/bounceEasing) instead of a flat
                    // linear settle.
                    scale: 1.0
                    NumberAnimation { id: calcPressDown;  target: calcBtn; property: "scale"; to: 0.95; duration: Theme.press; easing.type: Easing.OutQuad }
                    NumberAnimation { id: calcBounceBack; target: calcBtn; property: "scale"; to: 1.0;  duration: Theme.bounceDuration; easing.type: Theme.bounceEasing; easing.overshoot: Theme.bounceOvershoot }
                    TapHandler {
                        id: calcTap
                        onPressedChanged: {
                            if (pressed) { calcBounceBack.stop(); calcPressDown.restart() }
                            else { calcPressDown.stop(); calcBounceBack.restart() }
                        }
                        onTapped: root.calcFormula()
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.result !== ""
                    spacing: Theme.sp2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.sp2
                        Item {
                            height: resultNumText.implicitHeight
                            width:  resultNumText.implicitWidth
                            // Glow bloom in dark mode
                            Rectangle {
                                visible: Theme.dark
                                anchors.centerIn: parent
                                width:  parent.width + Math.round(24 * Theme.scale)
                                height: parent.height + Math.round(12 * Theme.scale)
                                radius: Math.round(14 * Theme.scale)
                                color:  Theme.glowB2
                            }
                            Text {
                                id: resultNumText
                                text: root.result
                                color: Theme.text
                                font.family: Theme.fontMono; font.weight: Font.Medium
                                font.pixelSize: Math.round(26 * Theme.scale)
                            }
                        }
                        Text { text: root.resultUnit; color: Theme.textDim; font.family: Theme.fontSans; font.pixelSize: Math.round(13 * Theme.scale) }
                        Item { Layout.fillWidth: true }
                    }
                    RowLayout {
                        spacing: Theme.sp4
                        Text {
                            text: "copy"; color: Theme.textDim; font.family: Theme.fontSans; font.pixelSize: Math.round(12 * Theme.scale)
                            TapHandler { onTapped: root.copyResult() }
                        }
                        Text {
                            text: "→ Calc"; color: Theme.textDim; font.family: Theme.fontSans; font.pixelSize: Math.round(12 * Theme.scale)
                            TapHandler { onTapped: if (root.window) { root.window.currentTab = 0; root.window.showToast("Sent to calculator") } }
                        }
                    }
                }
            }
        }
    }
}
