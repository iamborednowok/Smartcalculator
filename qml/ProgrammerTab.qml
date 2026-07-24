import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "components"

// ProgrammerTab v3 — BASE CONVERSION + BIT MANIPULATION, now orientation-
// aware: landscape gets a 3-card row (Display | Bit Grid | Ops), portrait
// keeps the vertical stack (see root.wide). The plain TextField from v2
// is back to being a real tappable keypad ("Input Card") — see padDigits/
// digitEnabled/appendDigit above.
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

    // Landscape → 3-card row (Display | Bit Grid | Ops), matching the
    // reference layout; portrait → the original vertical stack. Read from
    // the window's orientation-driven isWide (see Main.qml), not a local
    // width check, so this tab reflows the instant the device rotates.
    readonly property bool wide: !!(window && window.isWide)

    // ── State ─────────────────────────────────────────────────────────
    property int    bitWidth:  32        // 8 | 16 | 32 | 64
    property int    inputBase: 10        // 10 | 16 | 8 | 2
    property string rawInput:  ""
    property string pendingOp: ""
    property double pendingVal: 0

    // ── Current integer value (clamped to bitWidth) ────────────────────
    property double currentVal: {
        if (rawInput === "" || rawInput === "-") return 0
        var n = inputBase === 16 ? parseInt(rawInput, 16)
              : inputBase === 2  ? parseInt(rawInput, 2)
              : inputBase === 8  ? parseInt(rawInput, 8)
              : parseFloat(rawInput)
        return isNaN(n) ? 0 : clamp(Math.trunc(n))
    }

    function clamp(n) {
        var cap = Math.pow(2, bitWidth)
        return ((Math.trunc(n) % cap) + cap) % cap
    }

    // ── Bit helpers — float-safe (no >> or ^ operator) ────────────────
    function bitAt(pos) {
        return Math.floor(currentVal / Math.pow(2, pos)) % 2 !== 0 ? 1 : 0
    }
    function toggleBit(pos) {
        var p = Math.pow(2, pos)
        var toggled = bitAt(pos) === 1 ? currentVal - p : currentVal + p
        currentVal = clamp(toggled)
        rawInput = currentVal.toString(inputBase).toUpperCase()
    }

    // ── Base conversions / display ─────────────────────────────────────
    function fmtDec(v) { return String(Math.trunc(v)) }
    function fmtHex(v) {
        var h = clamp(v).toString(16).toUpperCase()
        while (h.length < Math.ceil(bitWidth / 4)) h = "0" + h
        return h.match(/.{1,4}/g).join(" ")
    }
    function fmtOct(v) { return clamp(v).toString(8) }
    function fmtBin(v) {
        var b = clamp(v).toString(2)
        while (b.length < bitWidth) b = "0" + b
        return b.match(/.{1,8}/g).join("  ")
    }
    function fmtForBase(v, base) {
        if (base === 10) return fmtDec(v)
        if (base === 16) return "0x " + fmtHex(v)
        if (base === 8)  return "0o " + fmtOct(v)
        return fmtBin(v)
    }
    function switchBase(base) {
        var v = currentVal
        inputBase = base
        rawInput = v === 0 ? "" : (base === 10 ? fmtDec(v) : v.toString(base).toUpperCase())
    }

    // ── Ops (bitwise-safe hi/lo decomposition for 64-bit) ─────────────
    function doOp(op) {
        if (op === "NOT") {
            currentVal = clamp(Math.pow(2, bitWidth) - 1 - currentVal)
            rawInput = currentVal.toString(inputBase).toUpperCase()
            return
        }
        if (pendingOp === "" || rawInput === "") {
            pendingOp  = op
            pendingVal = currentVal
            rawInput   = ""
            return
        }
        var a = pendingVal, b = currentVal, result = 0
        switch (op) {
            case "=":
                switch (pendingOp) {
                    case "AND": result = bitWidth <= 32 ? ((a & b) >>> 0) : bwAnd64(a,b); break
                    case "OR":  result = bitWidth <= 32 ? ((a | b) >>> 0) : bwOr64(a,b);  break
                    case "XOR": result = bitWidth <= 32 ? ((a ^ b) >>> 0) : bwXor64(a,b); break
                    case "<<":  result = a * Math.pow(2, b); break
                    case ">>":  result = Math.trunc(a / Math.pow(2, b)); break
                }
                break
            default: return
        }
        currentVal = clamp(result)
        rawInput   = currentVal.toString(inputBase).toUpperCase()
        pendingOp  = ""; pendingVal = 0
        resultFlash.restart()
    }

    // 64-bit safe via hi/lo
    function bwAnd64(a,b){
        var aH=Math.floor(a/4294967296),aL=a%4294967296,bH=Math.floor(b/4294967296),bL=b%4294967296
        return ((aH&bH)>>>0)*4294967296+((aL&bL)>>>0)
    }
    function bwOr64(a,b){
        var aH=Math.floor(a/4294967296),aL=a%4294967296,bH=Math.floor(b/4294967296),bL=b%4294967296
        return ((aH|bH)>>>0)*4294967296+((aL|bL)>>>0)
    }
    function bwXor64(a,b){
        var aH=Math.floor(a/4294967296),aL=a%4294967296,bH=Math.floor(b/4294967296),bL=b%4294967296
        return ((aH^bH)>>>0)*4294967296+((aL^bL)>>>0)
    }

    readonly property var baseItems: [
        { label:"DEC", value:10 }, { label:"HEX", value:16 },
        { label:"OCT", value:8  }, { label:"BIN", value:2  }
    ]
    readonly property var widthItems: [
        { label:"8",  value:8  }, { label:"16", value:16 },
        { label:"32", value:32 }, { label:"64", value:64 }
    ]
    readonly property var hexDigits: ["A","B","C","D","E","F"]
    readonly property var opsRow: ["AND","OR","XOR","NOT","<<",">>"]
    readonly property var baseNames: ({ 10: "DEC", 16: "HEX", 8: "OCT", 2: "BIN" })
    // Full 0-F digit pad — Input Card below is a real tappable keypad now
    // instead of a plain text field, so both the digits and the enabled/
    // disabled rule live here rather than only inside one TextField
    // handler.
    readonly property var padDigits: ["0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F"]
    function digitEnabled(d) {
        var v = parseInt(d, 16)
        if (root.inputBase === 16) return true
        if (root.inputBase === 10) return v <= 9
        if (root.inputBase === 8)  return v <= 7
        return v <= 1
    }
    function appendDigit(d) {
        if (!digitEnabled(d)) return
        var t = root.rawInput + d
        var valid = root.inputBase === 16 ? /^[0-9A-F]*$/.test(t)
                  : root.inputBase === 2  ? /^[01]*$/.test(t)
                  : root.inputBase === 8  ? /^[0-7]*$/.test(t)
                  : /^[0-9]*$/.test(t)
        if (valid) root.rawInput = t
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: Theme.sp4
        contentHeight: col.implicitHeight
        clip: true

        ColumnLayout {
            id: col
            width: parent.width
            spacing: Theme.sp3

            // ── Ribbons ────────────────────────────────────────────────
            GroupTabs {
                Layout.fillWidth: true
                model: root.baseItems
                currentValue: root.inputBase
                onSelected: function(v) { root.switchBase(v) }
            }
            GroupTabs {
                Layout.fillWidth: false
                model: root.widthItems
                currentValue: root.bitWidth
                onSelected: function(v) { root.bitWidth = v }
            }

            // ── Landscape: Display | Bit Grid | Ops side by side.
            // Portrait: same three cards, one per row. One `columns`
            // binding drives both — see root.wide (Main.qml's
            // orientation-based isWide, not a width breakpoint).
            GridLayout {
                id: cardGrid
                Layout.fillWidth: true
                columns: root.wide ? 3 : 1
                columnSpacing: Theme.sp3
                rowSpacing: Theme.sp3

                // ── Display Card ─────────────────────────────────────
                Rectangle {
                    id: displayCard
                    Layout.fillWidth: true
                    Layout.fillHeight: root.wide
                    Layout.preferredWidth: root.wide ? Math.round((col.width - Theme.sp3 * 2) * 0.30) : -1
                    Layout.preferredHeight: displayCol.implicitHeight + Theme.sp4 * 2
                    radius: Theme.rMd
                    color: Theme.dark ? Theme.surfaceEq : Theme.surface

                    Rectangle {
                        anchors.fill: parent; anchors.margins: -1
                        radius: parent.radius + 1
                        color: "transparent"; border.width: 1; border.color: Theme.edgeA
                    }

                    SequentialAnimation {
                        id: resultFlash
                        NumberAnimation { target: displayCard; property: "opacity"; to: 0.4; duration: 60 }
                        NumberAnimation { target: displayCard; property: "opacity"; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
                    }

                    ColumnLayout {
                        id: displayCol
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        anchors.margins: Theme.sp4
                        spacing: Theme.sp2

                        Text {
                            text: "DISPLAY"
                            font.family: Theme.fontSans; font.weight: Font.Bold
                            font.pixelSize: Math.round(9 * Theme.scale); color: Theme.textFaint
                        }

                        // Primary base — large (smaller when squeezed into
                        // a landscape third-column rather than full width)
                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            text: root.fmtForBase(root.currentVal, root.inputBase)
                            font.family: Theme.fontMono
                            font.weight: Font.Medium
                            font.pixelSize: Math.round((root.inputBase === 2 ? 13 : (root.wide ? 20 : 28)) * Theme.scale)
                            color: Theme.text
                            elide: Text.ElideLeft
                            wrapMode: root.inputBase === 2 ? Text.WrapAnywhere : Text.NoWrap
                        }

                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.surface2 }

                        // Other 3 bases — compact
                        Repeater {
                            model: [10, 16, 8, 2].filter(function(b) { return b !== root.inputBase })
                            delegate: RowLayout {
                                Layout.fillWidth: true; spacing: Theme.sp2
                                Text {
                                    text: root.baseNames[modelData]
                                    font.family: Theme.fontSans; font.weight: Font.Bold
                                    font.pixelSize: Math.round(9 * Theme.scale); color: Theme.textFaint
                                }
                                Text {
                                    Layout.fillWidth: true; horizontalAlignment: Text.AlignRight
                                    text: root.fmtForBase(root.currentVal, modelData)
                                    font.family: Theme.fontMono; font.pixelSize: Math.round(11 * Theme.scale)
                                    color: Theme.textDim; elide: Text.ElideLeft
                                }
                                TapHandler { onTapped: root.switchBase(modelData) }
                            }
                        }
                    }
                }

                // ── Bit Grid Card — the hero ──────────────────────────
                Rectangle {
                    id: bitGridCard
                    Layout.fillWidth: true
                    Layout.fillHeight: root.wide
                    Layout.preferredWidth: root.wide ? Math.round((col.width - Theme.sp3 * 2) * 0.42) : -1
                    Layout.preferredHeight: bitGridCol.implicitHeight + Theme.sp4 * 2
                    radius: Theme.rMd
                    color: Theme.surface

                    Rectangle {
                        anchors.fill: parent; anchors.margins: -1
                        radius: parent.radius + 1
                        color: "transparent"; border.width: 1
                        border.color: Theme.glowColor(Theme.gradB, 0.5)
                    }

                    ColumnLayout {
                        id: bitGridCol
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        anchors.margins: Theme.sp4
                        spacing: Theme.sp2

                        Text {
                            text: "BIT GRID"
                            font.family: Theme.fontSans; font.weight: Font.Bold
                            font.pixelSize: Math.round(9 * Theme.scale); color: Theme.textFaint
                        }

                        Column {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: Theme.sp1

                            Repeater {
                                model: root.bitWidth / 8   // rows = bytes
                                delegate: Row {
                                    spacing: Math.round(3 * Theme.scale)
                                    readonly property int byteIdx: (root.bitWidth / 8) - 1 - index

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "B" + byteIdx
                                        width: Math.round(20 * Theme.scale)
                                        font.family: Theme.fontMono
                                        font.pixelSize: Math.round(8 * Theme.scale)
                                        color: Theme.textFaint
                                    }

                                    Repeater {
                                        model: 8
                                        delegate: Item {
                                            id: bitCell
                                            readonly property int bitPos: byteIdx * 8 + (7 - index)
                                            readonly property int bitVal: root.bitAt(bitPos)
                                            readonly property bool msb: bitPos === root.bitWidth - 1

                                            // FIX: cell size used to be derived by dividing
                                            // whatever width the tab happened to have by 8 —
                                            // that assumed the grid always spanned the full
                                            // tab width, which stopped being true once it
                                            // became one of three side-by-side cards in
                                            // landscape. A fixed, scaled size works in both.
                                            width:  Math.round(30 * Theme.scale)
                                            height: width

                                            // Small pop on toggle, alongside the existing
                                            // color/opacity flash below — a bit flipping
                                            // reads more like a physical switch this way.
                                            scale: 1.0
                                            SequentialAnimation {
                                                id: bitPop
                                                running: false
                                                NumberAnimation { target: bitCell; property: "scale"; to: 1.18; duration: 60; easing.type: Easing.OutQuad }
                                                NumberAnimation { target: bitCell; property: "scale"; to: 1.0;  duration: Theme.bounceDuration; easing.type: Theme.bounceEasing; easing.overshoot: Theme.bounceOvershoot }
                                            }

                                            Rectangle {
                                                visible: bitVal === 1 && Theme.dark
                                                anchors.centerIn: parent
                                                width:  parent.width  + Math.round(6 * Theme.scale)
                                                height: parent.height + Math.round(6 * Theme.scale)
                                                radius: Theme.rSm + 3
                                                color: Theme.glowColor(Theme.gradB, Theme.glowOp)
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: Theme.rSm
                                                // Lit bits are all green now (used to be red for
                                                // the MSB, blue for the rest) — one consistent
                                                // "on" color reads like a real indicator light;
                                                // the MSB keeps a thin red ring so which bit is
                                                // the sign bit is still visible at a glance.
                                                color: bitVal === 1 ? Theme.gradB : Theme.surface2
                                                border.width: msb ? 1 : 0
                                                border.color: Theme.glowColor(Theme.accent, 0.7)
                                                Behavior on color { ColorAnimation { duration: 90 } }

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: bitVal
                                                    font.family: Theme.fontMono
                                                    font.weight: Font.Bold
                                                    font.pixelSize: Math.round(9 * Theme.scale)
                                                    color: bitVal === 1 ? Theme.textOnAccent : Theme.textFaint
                                                }

                                                Rectangle {
                                                    id: bitPress; anchors.fill: parent; radius: parent.radius
                                                    color: Theme.textOnAccent; opacity: 0
                                                    SequentialAnimation on opacity {
                                                        id: bitFlash
                                                        running: false
                                                        NumberAnimation { to: 0.25; duration: 50 }
                                                        NumberAnimation { to: 0;    duration: 100 }
                                                    }
                                                }
                                            }

                                            TapHandler { onTapped: { bitFlash.restart(); bitPop.restart(); root.toggleBit(bitPos) } }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Ops Card ───────────────────────────────────────────
                Rectangle {
                    id: opsCard
                    Layout.fillWidth: true
                    Layout.fillHeight: root.wide
                    Layout.preferredWidth: root.wide ? Math.round((col.width - Theme.sp3 * 2) * 0.28) : -1
                    Layout.preferredHeight: opsCol.implicitHeight + Theme.sp4 * 2
                    radius: Theme.rMd
                    color: Theme.dark ? Theme.surfaceOp : Theme.surface

                    Rectangle {
                        anchors.fill: parent; anchors.margins: -1
                        radius: parent.radius + 1
                        color: "transparent"; border.width: 1; border.color: Theme.edgeB
                    }

                    ColumnLayout {
                        id: opsCol
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        anchors.margins: Theme.sp4
                        spacing: Theme.sp2

                        Text {
                            text: "OPS CARD"
                            font.family: Theme.fontSans; font.weight: Font.Bold
                            font.pixelSize: Math.round(9 * Theme.scale); color: Theme.textFaint
                        }

                        Text {
                            visible: root.pendingOp !== ""
                            text: root.pendingOp + " " + root.pendingVal.toString(root.inputBase).toUpperCase() + " …"
                            color: Theme.accent2
                            font.family: Theme.fontMono
                            font.pixelSize: Math.round(10 * Theme.scale)
                        }

                        // Each op gets its own hue from the shared per-tab
                        // palette — purely decorative variety, matching the
                        // multicolor button row in the reference layout.
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: Theme.sp2
                            rowSpacing: Theme.sp2

                            Repeater {
                                model: root.opsRow
                                delegate: Rectangle {
                                    id: opBtn
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Math.round(34 * Theme.scale)
                                    radius: Theme.rMd
                                    readonly property color hue: Theme.tabColors[(index + 2) % Theme.tabColors.length]
                                    color: Theme.glowColor(hue, Theme.dark ? 0.20 : 0.14)
                                    border.width: 1
                                    border.color: Theme.glowColor(hue, Theme.dark ? 0.55 : 0.30)

                                    // Blur bloom behind the button (dark mode
                                    // only, z:-1 so it renders behind the
                                    // button's own fill) — the border alone
                                    // read as flat next to the reference's
                                    // clearly-glowing buttons.
                                    Rectangle {
                                        z: -1
                                        visible: Theme.dark
                                        anchors.centerIn: parent
                                        width:  parent.width  + Math.round(10 * Theme.scale)
                                        height: parent.height + Math.round(10 * Theme.scale)
                                        radius: parent.radius + 4
                                        color: Theme.glowColor(hue, Theme.glowOp * 0.7)
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData
                                        font.family: Theme.fontMono
                                        font.pixelSize: Math.round(12 * Theme.scale)
                                        color: hue
                                    }

                                    scale: 1.0
                                    NumberAnimation { id: opPressDown;  target: opBtn; property: "scale"; to: 0.90; duration: Theme.press; easing.type: Easing.OutQuad }
                                    NumberAnimation { id: opBounceBack; target: opBtn; property: "scale"; to: 1.0;  duration: Theme.bounceDuration; easing.type: Theme.bounceEasing; easing.overshoot: Theme.bounceOvershoot }
                                    TapHandler {
                                        onPressedChanged: {
                                            if (pressed) { opBounceBack.stop(); opPressDown.restart() }
                                            else { opPressDown.stop(); opBounceBack.restart() }
                                        }
                                        onTapped: root.doOp(modelData)
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: execBtn
                            Layout.fillWidth: true
                            Layout.topMargin: Theme.sp1
                            Layout.preferredHeight: Math.round(36 * Theme.scale)
                            radius: Theme.rMd
                            visible: root.pendingOp !== ""
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Theme.gradA }
                                GradientStop { position: 0.5; color: Theme.gradB }
                                GradientStop { position: 1.0; color: Theme.gradC }
                            }
                            // Missing on this one specifically until now — every
                            // other hero button has this ring; added for consistency.
                            Rectangle {
                                anchors.fill: parent; anchors.margins: -2; radius: parent.radius + 2
                                color: "transparent"; border.width: 2; border.color: Theme.edgeA
                            }
                            Text { anchors.centerIn: parent; text: "= Execute"; color: Theme.textOnAccent; font.family: Theme.fontMono; font.weight: Font.Bold; font.pixelSize: Math.round(13 * Theme.scale) }

                            scale: 1.0
                            NumberAnimation { id: execPressDown;  target: execBtn; property: "scale"; to: 0.95; duration: Theme.press; easing.type: Easing.OutQuad }
                            NumberAnimation { id: execBounceBack; target: execBtn; property: "scale"; to: 1.0;  duration: Theme.bounceDuration; easing.type: Theme.bounceEasing; easing.overshoot: Theme.bounceOvershoot }
                            TapHandler {
                                onPressedChanged: {
                                    if (pressed) { execBounceBack.stop(); execPressDown.restart() }
                                    else { execPressDown.stop(); execBounceBack.restart() }
                                }
                                onTapped: root.doOp("=")
                            }
                        }
                    }
                }
            }

            // ── Input Card — real tap-to-enter keypad ───────────────────
            // Replaces the old free-text field + separate dimmed A-F row.
            // Both reference images show a proper keypad here rather than
            // a text box, and it reuses the exact same base-validation
            // rule the old TextField handler had (see digitEnabled/
            // appendDigit above) so nothing about *what's* a valid entry
            // changed, only *how* you enter it.
            Rectangle {
                Layout.fillWidth: true
                radius: Theme.rMd
                color: Theme.surface
                Layout.preferredHeight: inputCol.implicitHeight + Theme.sp4 * 2

                Rectangle {
                    anchors.fill: parent; anchors.margins: -1
                    radius: parent.radius + 1
                    color: "transparent"; border.width: 1
                    border.color: Theme.glowColor(Theme.accent2, 0.4)
                }

                ColumnLayout {
                    id: inputCol
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: Theme.sp4
                    spacing: Theme.sp2

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "INPUT CARD"
                            font.family: Theme.fontSans; font.weight: Font.Bold
                            font.pixelSize: Math.round(9 * Theme.scale); color: Theme.textFaint
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            Layout.maximumWidth: Math.round(160 * Theme.scale)
                            text: root.rawInput.length ? root.rawInput : "0"
                            font.family: Theme.fontMono; font.pixelSize: Math.round(12 * Theme.scale)
                            color: Theme.textDim
                            elide: Text.ElideLeft
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: root.wide ? 9 : 6   // 18 keys either way: 2×9 or 3×6, no ragged last row
                        columnSpacing: Theme.sp2
                        rowSpacing: Theme.sp2

                        Repeater {
                            model: root.padDigits
                            delegate: Rectangle {
                                id: padKey
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.round(40 * Theme.scale)
                                radius: Theme.rMd
                                readonly property bool keyEnabled: root.digitEnabled(modelData)
                                color: Theme.surface2
                                opacity: keyEnabled ? 1.0 : 0.32
                                Behavior on opacity { NumberAnimation { duration: Theme.press } }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.family: Theme.fontMono; font.weight: Font.Medium
                                    font.pixelSize: Math.round(15 * Theme.scale)
                                    color: Theme.text
                                }

                                scale: 1.0
                                NumberAnimation { id: keyPressDown;  target: padKey; property: "scale"; to: 0.88; duration: Theme.press; easing.type: Easing.OutQuad }
                                NumberAnimation { id: keyBounceBack; target: padKey; property: "scale"; to: 1.0;  duration: Theme.bounceDuration; easing.type: Theme.bounceEasing; easing.overshoot: Theme.bounceOvershoot }
                                TapHandler {
                                    enabled: padKey.keyEnabled
                                    onPressedChanged: {
                                        if (pressed) { keyBounceBack.stop(); keyPressDown.restart() }
                                        else { keyPressDown.stop(); keyBounceBack.restart() }
                                    }
                                    onTapped: root.appendDigit(modelData)
                                }
                            }
                        }

                        Rectangle {
                            id: backspaceKey
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.round(40 * Theme.scale)
                            radius: Theme.rMd
                            color: Theme.surface2
                            Text { anchors.centerIn: parent; text: "←"; color: Theme.accent; font.pixelSize: Math.round(16 * Theme.scale) }
                            scale: 1.0
                            NumberAnimation { id: bsPressDown;  target: backspaceKey; property: "scale"; to: 0.88; duration: Theme.press; easing.type: Easing.OutQuad }
                            NumberAnimation { id: bsBounceBack; target: backspaceKey; property: "scale"; to: 1.0;  duration: Theme.bounceDuration; easing.type: Theme.bounceEasing; easing.overshoot: Theme.bounceOvershoot }
                            TapHandler {
                                onPressedChanged: {
                                    if (pressed) { bsBounceBack.stop(); bsPressDown.restart() }
                                    else { bsPressDown.stop(); bsBounceBack.restart() }
                                }
                                onTapped: if (root.rawInput.length > 0) root.rawInput = root.rawInput.slice(0, -1)
                            }
                        }
                        Rectangle {
                            id: clearKey
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.round(40 * Theme.scale)
                            radius: Theme.rMd
                            color: Theme.glowColor(Theme.accent, Theme.dark ? 0.22 : 0.14)
                            Text { anchors.centerIn: parent; text: "C"; color: Theme.accent; font.family: Theme.fontSans; font.weight: Font.Bold; font.pixelSize: Math.round(14 * Theme.scale) }
                            scale: 1.0
                            NumberAnimation { id: clearPressDown;  target: clearKey; property: "scale"; to: 0.88; duration: Theme.press; easing.type: Easing.OutQuad }
                            NumberAnimation { id: clearBounceBack; target: clearKey; property: "scale"; to: 1.0;  duration: Theme.bounceDuration; easing.type: Theme.bounceEasing; easing.overshoot: Theme.bounceOvershoot }
                            TapHandler {
                                onPressedChanged: {
                                    if (pressed) { clearBounceBack.stop(); clearPressDown.restart() }
                                    else { clearPressDown.stop(); clearBounceBack.restart() }
                                }
                                onTapped: { root.rawInput = ""; root.pendingOp = ""; root.pendingVal = 0 }
                            }
                        }
                    }
                }
            }

            // ── Footer ────────────────────────────────────────────────
            Text {
                Layout.alignment: Qt.AlignRight
                text: "→ Calc"
                color: Theme.textDim
                font.family: Theme.fontSans
                font.pixelSize: Math.round(11 * Theme.scale)
                TapHandler { onTapped: if (root.window) { root.window.currentTab = 0; root.window.showToast("Sent to Calc", true) } }
            }
        }
    }
}
