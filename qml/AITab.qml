import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import SmartCalc.Backend 1.0
import "components"

Item {
    id: root
    property var window: ApplicationWindow.window

    // ── Conversation state ────────────────────────────────────────────
    property var messages: []
    property bool loading: false
    property string inputText: ""

    // ── BUG FIX: all 7 uses now correctly use window.appSettings ──────
    function handleResponse(content, isError) {
        loading = false
        var parsed = tryParseJson(content)
        var time   = Qt.formatTime(new Date(), "hh:mm")
        messages = messages.concat([{
            role:    "assistant",
            content: parsed ? parsed.answer : content,
            engine:  window && window.appSettings.orKey ? "openrouter" : "claude",
            time:    time,
            steps:   parsed ? (parsed.steps || []) : [],
            expr:    parsed ? (parsed.expression || "") : "",
            note:    parsed ? (parsed.note || "") : "",
            isError: isError
        }])
        scrollTimer.restart()
    }

    function tryParseJson(raw) {
        try {
            var clean = raw.replace(/```json|```/g, "").trim()
            return JSON.parse(clean)
        } catch(e) { return null }
    }

    function sendMessage(text) {
        var userText = text || inputText.trim()
        if (!userText || loading) return
        inputText = ""
        loading   = true

        var time = Qt.formatTime(new Date(), "hh:mm")
        messages = messages.concat([{ role: "user", content: userText, time: time }])
        scrollTimer.restart()

        var offlineResult = tryOfflineCalc(userText)
        if (offlineResult) {
            loading = false
            messages = messages.concat([{
                role: "assistant", content: offlineResult.answer,
                engine: "offline", time: Qt.formatTime(new Date(), "hh:mm"),
                steps: offlineResult.steps || [], expr: offlineResult.expr || "",
                note: "⚡ Computed offline", isError: false
            }])
            scrollTimer.restart()
            return
        }

        var apiMsgs = []
        for (var i = 0; i < messages.length; i++) {
            var m = messages[i]
            if (m.role === "user" || m.role === "assistant")
                apiMsgs.push({ role: m.role, content: m.content })
        }

        var systemPrompt = 'You are a math assistant. Respond ONLY with raw JSON:\n'
            + '{"answer":"final answer","steps":["step1","step2"],"expression":"optional math","note":"optional"}\n'
            + 'IMPORTANT: answer field must be a string. For graph requests add graphExprs array.'

        // BUG FIX: was window.settings.orKey — now window.appSettings.orKey
        var orKey = window ? window.appSettings.orKey : ""
        var model = orKey ? "meta-llama/llama-3.3-70b-instruct:free" : "claude-sonnet-4-20250514"
        apiClient.sendToAI(systemPrompt, apiMsgs, orKey, model)
    }

    function tryOfflineCalc(text) {
        var t = text.toLowerCase().trim()
        var clean = t
            .replace(/^(what is|calculate|compute|find|evaluate|solve)\s+/i, "")
            .replace(/×/g,"*").replace(/÷/g,"/").replace(/−/g,"-").replace(/π/g,"3.14159265358979")

        if (/^[\d\s\+\-\*\/\^\(\)\.%e]+$/.test(clean)) {
            var r = mathEngine.evaluate(clean, true, false)
            if (r !== "Error") return { answer: r, steps: [clean + " = " + r], expr: clean }
        }

        var pctMatch = text.match(/([\d.]+)%\s+of\s+([\d.]+)/i)
        if (pctMatch) {
            var pct = parseFloat(pctMatch[1]), base = parseFloat(pctMatch[2])
            var res = pct * base / 100
            return { answer: mathEngine.formatNumber(res),
                     steps: [pct + "% × " + base + " = " + mathEngine.formatNumber(res)],
                     expr: pct + "% of " + base }
        }

        var tipMatch = text.match(/([\d.]+)%\s+tip.*\$([\d.]+)/i)
        if (tipMatch) {
            var tipPct = parseFloat(tipMatch[1]), bill = parseFloat(tipMatch[2])
            var tip = bill * tipPct / 100, total = bill + tip
            return { answer: "Tip: $" + tip.toFixed(2) + " · Total: $" + total.toFixed(2),
                     steps: ["Tip = " + tipPct + "% × $" + bill + " = $" + tip.toFixed(2),
                             "Total = $" + bill + " + $" + tip.toFixed(2) + " = $" + total.toFixed(2)] }
        }
        return null
    }

    readonly property var examples: [
        "15% tip on $84.50, split 3 people",
        "30% off $249.99",
        "$400k mortgage at 6.5% for 30 years",
        "compound interest $5k at 7% for 20 years",
        "area of circle radius 8.5",
        "standard deviation of 4 7 13 2"
    ]

    // ── UI ────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // ── Header bar ────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true; spacing: 8

            // Title + model chip
            Column {
                spacing: 3
                Text {
                    text: "AI Assistant"
                    font.pixelSize: 18; font.family: "DM Sans"; font.weight: Font.SemiBold
                    color: "#f0f0ff"
                }
                Rectangle {
                    height: 20; width: modelChipLbl.implicitWidth + 18; radius: 10
                    color: Qt.rgba(0.49, 0.23, 0.93, 0.14)
                    border.color: Qt.rgba(0.67, 0.55, 1.0, 0.32); border.width: 1
                    Text {
                        id: modelChipLbl
                        anchors.centerIn: parent
                        // BUG FIX: was window.settings.orKey
                        text: window && window.appSettings.orKey ? "⚡ OpenRouter" : "☁ Claude"
                        font.pixelSize: 9; font.family: "DM Sans"; color: "#A78BFA"
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Settings gear button
            Rectangle {
                width: 36; height: 36; radius: 12
                color: settingsPanel.visible ? Qt.rgba(0.49,0.23,0.93,0.22) : Qt.rgba(1,1,1,0.06)
                border.color: settingsPanel.visible ? Qt.rgba(0.67,0.55,1.0,0.45) : Qt.rgba(1,1,1,0.12)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }
                Text { anchors.centerIn: parent; text: "⚙"; color: "#9090c0"; font.pixelSize: 16 }
                MouseArea { anchors.fill: parent; onClicked: settingsPanel.visible = !settingsPanel.visible }
            }
        }

        // ── Settings panel (collapsible) ──────────────────────────────
        Rectangle {
            id: settingsPanel
            visible: false
            Layout.fillWidth: true
            height: visible ? spCol.implicitHeight + 28 : 0
            clip: true
            radius: 16
            color: Qt.rgba(0.02, 0.02, 0.12, 0.85)
            border.color: Qt.rgba(0.49, 0.23, 0.93, 0.28); border.width: 1
            Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutQuart } }

            // Top sheen
            Rectangle {
                anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.60; height: 1; y: 1; radius: 1
                color: Qt.rgba(1, 1, 1, 0.18)
            }

            ColumnLayout {
                id: spCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                spacing: 10

                Text {
                    text: "OPENROUTER API KEY"
                    font.pixelSize: 8; color: "#7070a8"; font.letterSpacing: 1.2; font.family: "DM Sans"
                }
                Text {
                    text: "Free key at openrouter.ai — unlocks Llama 3.3, Gemma 3 and more"
                    color: "#9090c8"; font.pixelSize: 10; wrapMode: Text.WordWrap; Layout.fillWidth: true
                }

                RowLayout { spacing: 8
                    StyledInput {
                        id: keyInput; Layout.fillWidth: true
                        placeholderText: "sk-or-v1-…"; echoMode: TextInput.Password
                        // BUG FIX: was window.settings.orKey
                        text: window ? window.appSettings.orKey : ""
                    }
                    Rectangle {
                        width: 64; height: 42; radius: 12
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#5B21B6" }
                            GradientStop { position: 1.0; color: "#7C3AED" }
                        }
                        Text { anchors.centerIn: parent; text: "Save"; color: "#fff"; font.pixelSize: 12; font.weight: Font.Medium }
                        MouseArea { anchors.fill: parent; onClicked: {
                            // BUG FIX: was window.settings.orKey
                            if (window) window.appSettings.orKey = keyInput.text
                            settingsPanel.visible = false
                            if (root.window) root.window.showToast("API key saved ✓", true)
                        }}
                    }
                }

                RowLayout {
                    // BUG FIX: was window.settings.orKey
                    visible: window && window.appSettings.orKey !== ""
                    spacing: 8
                    Rectangle { width: 8; height: 8; radius: 4; color: "#10B981"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Key active"; color: "#10B981"; font.pixelSize: 10; Layout.fillWidth: true }
                    Rectangle {
                        width: 58; height: 24; radius: 8
                        color: Qt.rgba(0.96,0.25,0.37,0.08); border.color: Qt.rgba(0.96,0.25,0.37,0.28); border.width: 1
                        Text { anchors.centerIn: parent; text: "Remove"; font.pixelSize: 9; color: "#F43F5E" }
                        MouseArea { anchors.fill: parent; onClicked: {
                            // BUG FIX: was window.settings.orKey
                            if(window) window.appSettings.orKey = ""
                            keyInput.text = ""
                        }}
                    }
                }
            }
        }

        // ── Messages area ─────────────────────────────────────────────
        Flickable {
            id: msgFlickable
            Layout.fillWidth: true; Layout.fillHeight: true
            contentHeight: msgCol.implicitHeight + 16
            clip: true

            ColumnLayout {
                id: msgCol
                width: parent.width; spacing: 10

                // Empty state: example chips
                Column {
                    visible: messages.length === 0 && !loading
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "Try asking…"
                        font.pixelSize: 10; color: "#44446a"; font.family: "DM Sans"
                        font.letterSpacing: 0.5
                        bottomPadding: 4
                    }

                    Repeater {
                        model: examples
                        delegate: Rectangle {
                            width: msgCol.width; height: 42; radius: 14
                            color: Qt.rgba(1, 1, 1, 0.04)
                            border.color: Qt.rgba(1, 1, 1, 0.09); border.width: 1

                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                                Text {
                                    text: "⚡"; font.pixelSize: 11; color: "#7C3AED"
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData; color: "#9090c8"; font.pixelSize: 12
                                    font.family: "DM Sans"; elide: Text.ElideRight
                                }
                                Text { text: "›"; font.pixelSize: 14; color: "#44446a" }
                            }
                            MouseArea { anchors.fill: parent; onClicked: sendMessage(modelData) }
                        }
                    }
                }

                // Message bubbles
                Repeater {
                    model: messages
                    delegate: ColumnLayout {
                        width: parent.width; spacing: 4

                        // ── User message ───────────────────────────────
                        Rectangle {
                            visible: modelData.role === "user"
                            Layout.alignment: Qt.AlignRight
                            Layout.maximumWidth: parent.width * 0.82
                            width: Math.min(uTxt.implicitWidth + 28, parent.width * 0.82)
                            height: uTxt.implicitHeight + 22
                            radius: 18; topRightRadius: 5
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Qt.rgba(0.36,0.23,0.93,0.32) }
                                GradientStop { position: 1.0; color: Qt.rgba(0.49,0.23,0.93,0.28) }
                            }
                            border.color: Qt.rgba(0.67,0.55,1.0,0.38); border.width: 1

                            Text {
                                id: uTxt
                                anchors.fill: parent; anchors.margins: 13
                                text: modelData.content || ""
                                color: "#f0f0ff"; font.pixelSize: 13
                                wrapMode: Text.WordWrap
                            }
                        }
                        Text {
                            visible: modelData.role === "user"
                            Layout.alignment: Qt.AlignRight
                            text: modelData.time || ""
                            font.pixelSize: 9; color: "#44446a"; rightPadding: 4
                        }

                        // ── Assistant message ──────────────────────────
                        Rectangle {
                            visible: modelData.role === "assistant"
                            Layout.fillWidth: true
                            height: aCol.implicitHeight + 24
                            radius: 18; topLeftRadius: 5
                            color: modelData.isError
                                ? Qt.rgba(0.96, 0.25, 0.37, 0.06)
                                : Qt.rgba(1, 1, 1, 0.055)
                            border.color: modelData.isError
                                ? Qt.rgba(0.96, 0.25, 0.37, 0.30)
                                : Qt.rgba(1, 1, 1, 0.12)
                            border.width: 1

                            // Top sheen
                            Rectangle {
                                anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width * 0.55; height: 1; y: 1; radius: 1
                                color: Qt.rgba(1,1,1, modelData.isError ? 0.06 : 0.10)
                            }

                            ColumnLayout {
                                id: aCol
                                anchors { left:parent.left; right:parent.right; top:parent.top; margins:14 }
                                spacing: 7

                                // Engine badge row
                                RowLayout { spacing: 6
                                    Rectangle {
                                        height: 20; radius: 10
                                        width: eBadge.implicitWidth + 16
                                        color: {
                                            if (modelData.engine === "offline")  return Qt.rgba(0.06,0.73,0.51,0.12)
                                            if (modelData.engine === "openrouter") return Qt.rgba(0.95,0.62,0.07,0.12)
                                            return Qt.rgba(0.49,0.23,0.93,0.12)
                                        }
                                        border.color: {
                                            if (modelData.engine === "offline")  return Qt.rgba(0.06,0.73,0.51,0.35)
                                            if (modelData.engine === "openrouter") return Qt.rgba(0.95,0.62,0.07,0.35)
                                            return Qt.rgba(0.49,0.23,0.93,0.30)
                                        }
                                        border.width: 1
                                        Text {
                                            id: eBadge; anchors.centerIn: parent
                                            text: modelData.engine === "offline" ? "⚡ offline"
                                                : modelData.engine === "openrouter" ? "☁ openrouter"
                                                : "☁ claude"
                                            font.pixelSize: 9; font.family: "DM Sans"
                                            color: modelData.engine === "offline" ? "#10B981"
                                                 : modelData.engine === "openrouter" ? "#F59E0B"
                                                 : "#A78BFA"
                                        }
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text { text: modelData.time || ""; font.pixelSize: 9; color: "#33335a" }
                                }

                                // Answer text
                                Text {
                                    text: modelData.content || ""
                                    color: modelData.isError ? "#FDA4AF" : "#f0f0ff"
                                    font.pixelSize: 16; font.weight: Font.Light
                                    wrapMode: Text.WordWrap; Layout.fillWidth: true
                                }

                                // Expression
                                Rectangle {
                                    visible: (modelData.expr || "") !== ""
                                    Layout.fillWidth: true
                                    height: exprTxt.implicitHeight + 14
                                    radius: 10
                                    color: Qt.rgba(0.49,0.23,0.93,0.08)
                                    border.color: Qt.rgba(0.49,0.23,0.93,0.22); border.width: 1
                                    Text {
                                        id: exprTxt
                                        anchors { fill: parent; leftMargin: 12; rightMargin: 12; topMargin: 7; bottomMargin: 7 }
                                        text: modelData.expr || ""
                                        color: "#A78BFA"; font.pixelSize: 11; font.family: "DM Mono"
                                        wrapMode: Text.WordWrap
                                    }
                                }

                                // Steps list
                                Column {
                                    visible: (modelData.steps || []).length > 0
                                    Layout.fillWidth: true; spacing: 4
                                    Repeater {
                                        model: modelData.steps || []
                                        delegate: RowLayout {
                                            width: parent.width; spacing: 8
                                            Rectangle {
                                                width: 20; height: 20; radius: 10
                                                color: Qt.rgba(0.02,0.71,0.83,0.12)
                                                Text { anchors.centerIn: parent; text: index+1
                                                    font.pixelSize: 9; color: "#06B6D4"; font.weight: Font.Bold }
                                            }
                                            Text {
                                                text: modelData; Layout.fillWidth: true
                                                color: "#9090cc"; font.pixelSize: 11; font.family: "DM Mono"
                                                wrapMode: Text.WordWrap
                                            }
                                        }
                                    }
                                }

                                // Note pill
                                Rectangle {
                                    visible: (modelData.note || "") !== ""
                                    height: noteTxt.implicitHeight + 12
                                    width: noteTxt.implicitWidth + 20; radius: 10
                                    color: Qt.rgba(0.06,0.73,0.51,0.09)
                                    border.color: Qt.rgba(0.06,0.73,0.51,0.28); border.width: 1
                                    Text {
                                        id: noteTxt; anchors.centerIn: parent
                                        text: "ⓘ " + (modelData.note||"")
                                        color: "#10B981"; font.pixelSize: 10
                                    }
                                }
                            }
                        }
                    }
                }

                // Typing dots
                Rectangle {
                    visible: loading
                    Layout.fillWidth: true; height: 52; radius: 18; topLeftRadius: 5
                    color: Qt.rgba(1,1,1,0.055); border.color: Qt.rgba(1,1,1,0.12); border.width: 1

                    Row {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 16; spacing: 7
                        Repeater { model: 3
                            delegate: Rectangle {
                                width: 8; height: 8; radius: 4
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: "#7C3AED" }
                                    GradientStop { position: 1.0; color: "#06B6D4" }
                                }
                                SequentialAnimation on y {
                                    running: true; loops: Animation.Infinite
                                    PauseAnimation  { duration: 140 * index }
                                    NumberAnimation { to: -8; duration: 260; easing.type: Easing.OutQuad }
                                    NumberAnimation { to:  0; duration: 260; easing.type: Easing.InQuad }
                                    PauseAnimation  { duration: 400 - 140 * index }
                                }
                            }
                        }
                        Text { text: "  Thinking…"; color: "#5555a0"; font.pixelSize: 12; anchors.verticalCenter: undefined; leftPadding: 2 }
                    }
                }

                Item { height: 4 }
            }
        }

        // ── Input row ─────────────────────────────────────────────────
        RowLayout { Layout.fillWidth: true; spacing: 8

            Rectangle {
                Layout.fillWidth: true
                height: Math.min(inputTA.implicitHeight + 4, 120)
                radius: 16
                color: Qt.rgba(1,1,1,0.055)
                border.color: inputTA.activeFocus ? Qt.rgba(0.49,0.23,0.93,0.65) : Qt.rgba(1,1,1,0.12)
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 150 } }

                // Focus glow
                Rectangle {
                    visible: inputTA.activeFocus
                    anchors.fill: parent; anchors.margins: -5
                    radius: parent.radius + 5
                    color: "transparent"
                    border.color: Qt.rgba(0.49,0.23,0.93,0.20); border.width: 1; z: -1
                }

                TextArea {
                    id: inputTA
                    anchors.fill: parent; anchors.margins: 12
                    text: inputText
                    placeholderText: "Ask anything…"
                    color: "#f0f0ff"; placeholderTextColor: "#44446a"
                    font.pixelSize: 14; font.family: "DM Sans"
                    wrapMode: Text.WordWrap; background: null
                    onTextChanged: inputText = text
                    Keys.onReturnPressed: function(e) {
                        if (!(e.modifiers & Qt.ShiftModifier)) { e.accepted = true; sendMessage() }
                    }
                }
            }

            // Send button
            Rectangle {
                width: 46; height: 46; radius: 14
                enabled: !loading && inputText.trim() !== ""
                opacity: enabled ? 1.0 : 0.35
                Behavior on opacity { NumberAnimation { duration: 120 } }

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: enabled ? "#5B21B6" : Qt.rgba(1,1,1,0.06) }
                    GradientStop { position: 1.0; color: enabled ? "#06B6D4" : Qt.rgba(1,1,1,0.06) }
                }
                border.color: enabled ? "transparent" : Qt.rgba(1,1,1,0.12); border.width: 1

                Text { anchors.centerIn: parent; text: "↑"; color: "#fff"; font.pixelSize: 20; font.weight: Font.Bold }
                MouseArea { anchors.fill: parent; enabled: parent.enabled; onClicked: sendMessage() }
            }
        }

        // ── Footer: clear + count ─────────────────────────────────────
        RowLayout {
            visible: messages.length > 0; Layout.fillWidth: true

            Rectangle {
                width: 80; height: 24; radius: 8
                color: "transparent"; border.color: Qt.rgba(0.96,0.25,0.37,0.25); border.width: 1
                Text { anchors.centerIn: parent; text: "clear chat"; font.pixelSize: 9; color: "#F43F5E" }
                MouseArea { anchors.fill: parent; onClicked: messages = [] }
            }
            Item { Layout.fillWidth: true }
            Text {
                text: Math.ceil(messages.length / 2) + " exchange" + (messages.length > 2 ? "s" : "")
                font.pixelSize: 9; color: "#44446a"
            }
        }
    }

    Timer { id: scrollTimer; interval: 50
        onTriggered: msgFlickable.contentY = Math.max(0, msgFlickable.contentHeight - msgFlickable.height) }
}
