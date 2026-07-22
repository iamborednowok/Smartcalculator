import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "components"

// ConvertTab v2 — bidirectional live conversion, units always visible.
// Both display values are editable: edit either one, the other updates.
// No hidden picker sheets — all units shown as chip rows below each field.
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

    // ── Categories & unit tables ──────────────────────────────────────
    readonly property var unitCategories: ({
        "Length":      ["mm","cm","m","km","in","ft","yd","mi"],
        "Weight":      ["g","kg","lb","oz","t"],
        "Temperature": ["°C","°F","K"],
        "Speed":       ["m/s","km/h","mph","knot"],
        "Volume":      ["ml","l","fl oz","cup","pt","gal"],
        "Time":        ["s","min","hr","day","wk","mo","yr"],
        "Data":        ["B","KB","MB","GB","TB","PB"],
    })
    readonly property var catNames: Object.keys(unitCategories)

    // ── State ─────────────────────────────────────────────────────────
    property string category: catNames[0]
    property string fromUnit: "m"
    property string toUnit:   "ft"
    property string fromVal:  ""
    property string toVal:    ""
    property bool   updating: false   // prevents bidirectional loop

    function changeCategory(cat) {
        category = cat
        var units = unitCategories[cat]
        fromUnit = units[0]
        toUnit   = units.length > 1 ? units[1] : units[0]
        fromVal  = ""; toVal = ""
    }

    function convert(val, from, to) {
        var n = parseFloat(val)
        if (isNaN(n) || val.trim() === "") return ""
        var r = mathEngine.convertUnit(n, from, to, category)
        return mathEngine.formatNumber(r)
    }

    // Editing the FROM field → compute TO
    function onFromEdited(text) {
        if (updating) return
        updating = true
        fromVal = text
        toVal   = convert(text, fromUnit, toUnit)
        updating = false
    }

    // Editing the TO field → compute FROM (reverse)
    function onToEdited(text) {
        if (updating) return
        updating = true
        toVal  = text
        fromVal = convert(text, toUnit, fromUnit)
        updating = false
    }

    function selectFromUnit(u) {
        fromUnit = u
        if (fromVal !== "") toVal = convert(fromVal, fromUnit, toUnit)
        else if (toVal !== "") fromVal = convert(toVal, toUnit, fromUnit)
    }

    function selectToUnit(u) {
        toUnit = u
        if (fromVal !== "") toVal = convert(fromVal, fromUnit, toUnit)
        else if (toVal !== "") fromVal = convert(toVal, toUnit, fromUnit)
    }

    function swapUnits() {
        var tmpU = fromUnit; fromUnit = toUnit; toUnit = tmpU
        var tmpV = fromVal;  fromVal  = toVal;  toVal  = tmpV
    }

    // Clipboard helper
    TextEdit { id: clipHelper; visible: false }
    function copyText(t) { clipHelper.text = t; clipHelper.selectAll(); clipHelper.copy() }

    // ── Layout ────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.sp4
        spacing: Theme.sp4

        // ── Category ribbon ───────────────────────────────────────────
        GroupTabs {
            Layout.fillWidth: true
            model: root.catNames
            currentValue: root.category
            onSelected: function(v) { root.changeCategory(v) }
        }

        // ── FROM display block ────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Theme.sp2
            spacing: Theme.sp2

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.sp2

                Text {
                    text: "FROM"
                    font.family: Theme.fontSans
                    font.weight: Font.Bold
                    font.pixelSize: Math.round(9 * Theme.scale)
                    color: Theme.textFaint
                    letterSpacing: 0.08
                }
                Item { Layout.fillWidth: true }
                Text {
                    visible: root.fromVal !== ""
                    text: "copy"
                    color: Theme.textDim
                    font.family: Theme.fontSans
                    font.pixelSize: Math.round(11 * Theme.scale)
                    TapHandler {
                        onTapped: {
                            root.copyText(root.fromVal + " " + root.fromUnit)
                            if (root.window) root.window.showToast("Copied", true)
                        }
                    }
                }
            }

            // Large editable input
            TextField {
                id: fromField
                Layout.fillWidth: true
                text: root.fromVal
                placeholderText: "0"
                horizontalAlignment: TextInput.AlignRight
                font.family: Theme.fontMono
                font.weight: Font.Medium
                font.pixelSize: Math.round(42 * Theme.scale)
                color: Theme.text
                placeholderTextColor: Theme.textFaint
                background: null
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                onTextEdited: root.onFromEdited(text)
            }

            // FROM unit chip row (always visible)
            Flickable {
                Layout.fillWidth: true
                height: Math.round(34 * Theme.scale)
                contentWidth: fromChips.implicitWidth
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Row {
                    id: fromChips
                    spacing: Theme.sp2
                    height: parent.height
                    Repeater {
                        model: root.unitCategories[root.category]
                        delegate: Rectangle {
                            readonly property bool sel: modelData === root.fromUnit
                            height: Math.round(30 * Theme.scale)
                            width: chipLbl.implicitWidth + Theme.sp3 * 2
                            radius: Theme.rFull
                            color: sel ? Theme.accent : Theme.surface
                            // Glow on selected chip (dark mode)
                            Rectangle {
                                visible: sel && Theme.dark
                                anchors.fill: parent
                                anchors.margins: -Math.round(4 * Theme.scale)
                                radius: Theme.rFull + 4
                                color: Theme.glowA
                            }
                            Text {
                                id: chipLbl
                                anchors.centerIn: parent
                                text: modelData
                                font.family: Theme.fontMono
                                font.pixelSize: Math.round(12 * Theme.scale)
                                color: sel ? Theme.onAccent : Theme.textDim
                            }
                            TapHandler { onTapped: root.selectFromUnit(modelData) }
                        }
                    }
                }
            }
        }

        // ── Swap row ──────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp3
            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.surface2 }

            // Swap button with gradient background
            Rectangle {
                width: Math.round(38 * Theme.scale); height: width; radius: width / 2
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.gradA }
                    GradientStop { position: 1.0; color: Theme.gradC }
                }
                // Glow ring
                Rectangle {
                    visible: Theme.dark
                    anchors.centerIn: parent
                    width: parent.width + Math.round(10 * Theme.scale)
                    height: width; radius: width / 2
                    color: Theme.glowA
                }
                Text { anchors.centerIn: parent; text: "⇄"; color: Theme.onAccent; font.pixelSize: Math.round(16 * Theme.scale) }
                scale: swapTap.pressed ? 0.90 : 1.0
                Behavior on scale { NumberAnimation { duration: Theme.press } }
                TapHandler { id: swapTap; onTapped: root.swapUnits() }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.surface2 }
        }

        // ── TO display block ──────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.sp2

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.sp2
                Text {
                    text: "TO"
                    font.family: Theme.fontSans
                    font.weight: Font.Bold
                    font.pixelSize: Math.round(9 * Theme.scale)
                    color: Theme.textFaint
                    letterSpacing: 0.08
                }
                Item { Layout.fillWidth: true }
                Text {
                    visible: root.toVal !== ""
                    text: "copy"
                    color: Theme.textDim
                    font.family: Theme.fontSans
                    font.pixelSize: Math.round(11 * Theme.scale)
                    TapHandler {
                        onTapped: {
                            root.copyText(root.toVal + " " + root.toUnit)
                            if (root.window) root.window.showToast("Copied", true)
                        }
                    }
                }
            }

            // Large result (also editable for reverse conversion)
            TextField {
                id: toField
                Layout.fillWidth: true
                text: root.toVal
                placeholderText: "—"
                horizontalAlignment: TextInput.AlignRight
                font.family: Theme.fontMono
                font.weight: Font.Medium
                font.pixelSize: Math.round(42 * Theme.scale)
                color: Theme.accent2
                placeholderTextColor: Theme.textFaint
                background: null
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                onTextEdited: root.onToEdited(text)
            }

            // TO unit chip row
            Flickable {
                Layout.fillWidth: true
                height: Math.round(34 * Theme.scale)
                contentWidth: toChips.implicitWidth
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Row {
                    id: toChips
                    spacing: Theme.sp2
                    height: parent.height
                    Repeater {
                        model: root.unitCategories[root.category]
                        delegate: Rectangle {
                            readonly property bool sel: modelData === root.toUnit
                            height: Math.round(30 * Theme.scale)
                            width: toChipLbl.implicitWidth + Theme.sp3 * 2
                            radius: Theme.rFull
                            color: sel ? Theme.accent2 : Theme.surface
                            // Glow on selected chip (dark mode)
                            Rectangle {
                                visible: sel && Theme.dark
                                anchors.fill: parent
                                anchors.margins: -Math.round(4 * Theme.scale)
                                radius: Theme.rFull + 4
                                color: Theme.glowB
                            }
                            Text {
                                id: toChipLbl
                                anchors.centerIn: parent
                                text: modelData
                                font.family: Theme.fontMono
                                font.pixelSize: Math.round(12 * Theme.scale)
                                color: sel ? Theme.onAccent : Theme.textDim
                            }
                            TapHandler { onTapped: root.selectToUnit(modelData) }
                        }
                    }
                }
            }
        }

        // ── Quick actions ─────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp4
            visible: root.toVal !== "" && root.toVal !== "Error"

            Text {
                text: "→ Calc"
                color: Theme.textDim
                font.family: Theme.fontSans
                font.weight: Font.Medium
                font.pixelSize: Math.round(12 * Theme.scale)
                TapHandler {
                    onTapped: if (root.window) {
                        root.window.currentTab = 0
                        root.window.showToast("Result sent to Calc", true)
                    }
                }
            }
            Item { Layout.fillWidth: true }
        }
    }
}
