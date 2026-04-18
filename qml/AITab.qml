import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import Qt.labs.settings 1.0
import SmartCalc.Backend 1.0
import "components"

Item {
    id: root
    property var window: ApplicationWindow.window

    FileHelper { id: fileHelper }

    // ── Persistent settings ────────────────────────────────────────────
    Settings {
        id: aiPrefs
        category: "AITabV80"
        property int orModelIdx: 0
    }

    // ── OpenRouter free model list ─────────────────────────────────────
    readonly property var orModels: [
        { id: "meta-llama/llama-3.3-70b-instruct:free", label: "Llama 3.3 70B",  badge: "free", color: "#60c8e8", desc: "Meta's flagship — best free reasoning" },
        { id: "google/gemma-3-27b-it:free",             label: "Gemma 3 27B",    badge: "free", color: "#70e8a8", desc: "Google's capable instruction model" },
        { id: "mistralai/mistral-7b-instruct:free",     label: "Mistral 7B",     badge: "free", color: "#e8a870", desc: "Fast & efficient, great for math" },
        { id: "openrouter/auto",                        label: "Auto-select",    badge: "🎲",   color: "#a090e8", desc: "OpenRouter picks best available" },
    ]

    // ── State ──────────────────────────────────────────────────────────
    property var    messages:      []
    property bool   loading:       false
    property string inputText:     ""

    property string attachedFileUrl:  ""
    property string attachedBase64:   ""
    property string attachedMime:     ""
    property string attachedFileName: ""
    property bool   attachedIsImage:  false

    property bool   modelDropOpen: false

    // ── File picker ────────────────────────────────────────────────────
    FileDialog {
        id: filePicker
        title: "Attach image or PDF"
        nameFilters: ["Images (*.jpg *.jpeg *.png *.webp *.gif)", "PDF files (*.pdf)", "All files (*)"]
        onAccepted: {
            var url  = selectedFile.toString()
            var mime = fileHelper.mimeTypeForFile(url)
            var b64  = fileHelper.readFileAsBase64(url)
            if (b64 === "") { root.window?.showToast("Could not read file", false); return }
            attachedFileUrl   = url
            attachedBase64    = b64
            attachedMime      = mime
            attachedFileName  = fileHelper.fileName(url)
            attachedIsImage   = mime.startsWith("image/")
            root.window?.showToast("Attached: " + attachedFileName, true)
        }
    }

    // ── Helpers ────────────────────────────────────────────────────────
    function handleResponse(content, isError) {
        loading = false
        var parsed = tryParseJson(content)
        var time   = Qt.formatTime(new Date(), "hh:mm")
        appendMsg({
            role:    "assistant",
            content: parsed ? parsed.answer : content,
            engine:  window && window.appSettings.orKey ? "openrouter" : "claude",
            model:   window && window.appSettings.orKey ? orModels[aiPrefs.orModelIdx].label : "Claude",
            time:    time,
            steps:   parsed ? (parsed.steps  || []) : [],
            expr:    parsed ? (parsed.expression || "") : "",
            note:    parsed ? (parsed.note   || "") : "",
            isError: isError
        })
    }

    function tryParseJson(raw) {
        try { return JSON.parse(raw.replace(/```json|```/g, "").trim()) }
        catch(e) { return null }
    }

    function appendMsg(m) {
        messages = messages.concat([m])
        scrollTimer.restart()
    }

    function clearAttachment() {
        attachedFileUrl = ""; attachedBase64 = ""; attachedMime = ""
        attachedFileName = ""; attachedIsImage = false
    }

    // ── Main send ──────────────────────────────────────────────────────
    function sendMessage(text) {
        var userText = text || inputText.trim()
        if (!userText && attachedBase64 === "") return
        if (loading) return

        var displayText = userText || ("📎 " + attachedFileName)
        inputText = ""
        loading   = true

        var time = Qt.formatTime(new Date(), "hh:mm")
        appendMsg({
            role:          "user",
            content:       displayText,
            time:          time,
            hasAttachment: attachedBase64 !== "",
            attachThumb:   attachedIsImage ? "data:" + attachedMime + ";base64," + attachedBase64.slice(0,200) : "",
            attachName:    attachedFileName,
            attachMime:    attachedMime
        })

        if (attachedBase64 !== "") {
            sendWithVision(userText || "Analyze this", attachedBase64, attachedMime)
            clearAttachment()
            return
        }
        clearAttachment()

        // Offline shortcut for pure arithmetic
        var offlineResult = tryOfflineCalc(userText)
        if (offlineResult) {
            loading = false
            appendMsg({
                role: "assistant", content: offlineResult.answer,
                engine: "offline", model: "offline", time: Qt.formatTime(new Date(), "hh:mm"),
                steps: offlineResult.steps || [], expr: offlineResult.expr || "",
                note: "⚡ Computed offline", isError: false
            })
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

        var orKey = window ? window.appSettings.orKey : ""
        var model = orKey ? orModels[aiPrefs.orModelIdx].id : "claude-sonnet-4-20250514"
        apiClient.sendToAI(systemPrompt, apiMsgs, orKey, model)
    }

    // ── Vision ─────────────────────────────────────────────────────────
    function sendWithVision(prompt, base64Data, mime) {
        var orKey   = window ? window.appSettings.orKey   : ""
        var anthKey = window ? window.appSettings.anthKey : ""

        if (!orKey && !anthKey) {
            loading = false
            appendMsg({
                role: "assistant", content: "Vision requires an API key. Add OpenRouter (free) or Anthropic key in settings.",
                engine: "claude", model: "Claude", time: Qt.formatTime(new Date(), "hh:mm"),
                steps: [], expr: "", note: "", isError: true
            })
            return
        }

        var xhr = new XMLHttpRequest()
        var url, headers, body

        if (orKey) {
            url = "https://openrouter.ai/api/v1/chat/completions"
            headers = { "Content-Type": "application/json", "Authorization": "Bearer " + orKey,
                        "HTTP-Referer": "https://smartcalc.app", "X-Title": "SmartCalc" }
            body = JSON.stringify({ model: "anthropic/claude-haiku-4-5", max_tokens: 800,
                messages: [{ role: "user", content: [
                    { type: "image_url", image_url: { url: "data:" + mime + ";base64," + base64Data } },
                    { type: "text", text: "You are a math assistant. " + prompt + '. JSON: {"answer":"...","steps":[],"expression":""}' }
                ]}]})
        } else {
            url = "https://api.anthropic.com/v1/messages"
            headers = { "Content-Type": "application/json", "x-api-key": anthKey, "anthropic-version": "2023-06-01" }
            body = JSON.stringify({ model: "claude-haiku-4-5-20251001", max_tokens: 800,
                messages: [{ role: "user", content: [
                    { type: "image",  source: { type: "base64", media_type: mime, data: base64Data } },
                    { type: "text",   text: "You are a math assistant. " + prompt + '. JSON: {"answer":"...","steps":[],"expression":""}' }
                ]}]})
        }

        xhr.open("POST", url, true)
        for (var h in headers) xhr.setRequestHeader(h, headers[h])
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            loading = false
            var time = Qt.formatTime(new Date(), "hh:mm")
            try {
                var resp   = JSON.parse(xhr.responseText)
                var raw    = orKey ? (resp.choices?.[0]?.message?.content || "No response")
                                   : (resp.content?.[0]?.text || "No response")
                var parsed = tryParseJson(raw)
                appendMsg({
                    role: "assistant", content: parsed ? parsed.answer : raw,
                    engine: orKey ? "openrouter" : "claude",
                    model: orKey ? "Vision" : "Claude Vision",
                    time: time,
                    steps: parsed ? (parsed.steps || []) : [], expr: parsed ? (parsed.expression || "") : "",
                    note: "📷 Vision analysis", isError: xhr.status < 200 || xhr.status >= 300
                })
            } catch(e) {
                appendMsg({ role: "assistant", content: "Vision error: " + e,
                    engine: "claude", model: "Claude", time: time, steps: [], expr: "", note: "", isError: true })
            }
        }
        xhr.send(body)
    }

    function tryOfflineCalc(text) {
        var t     = text.toLowerCase().trim()
        var clean = t.replace(/^(what is|calculate|compute|find|evaluate|solve)\s+/i, "")
                     .replace(/×/g,"*").replace(/÷/g,"/").replace(/−/g,"-").replace(/π/g,"3.14159265358979")

        if (/^[\d\s\+\-\*\/\^\(\)\.%e]+$/.test(clean)) {
            var r = mathEngine.evaluate(clean, true, false)
            if (r !== "Error") return { answer: r, steps: [clean + " = " + r], expr: clean }
        }

        var pctMatch = text.match(/([\d.]+)%\s+of\s+([\d.]+)/i)
        if (pctMatch) {
            var pct = parseFloat(pctMatch[1]), base2 = parseFloat(pctMatch[2])
            var res = pct * base2 / 100
            return { answer: mathEngine.formatNumber(res),
                     steps: [pct + "% × " + base2 + " = " + mathEngine.formatNumber(res)],
                     expr: pct + "% of " + base2 }
        }
        return null
    }

    readonly property var examples: [
        "15% tip on $84.50, split 3 people",
        "compound interest $5k at 7% for 20 years",
        "$400k mortgage at 6.5% for 30 years",
        "area of a sphere radius 12",
        "convert 75 mph to km/h",
        "📷 Snap a photo of an equation",
    ]

    // ── UI ─────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // ── Header ──────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true; spacing: 8

            Column {
                spacing: 3
                Text {
                    text: "AI Assistant"
                    font.pixelSize: 18; font.family: Theme.fontSans; font.weight: Font.SemiBold
                    color: Theme.text
                }
                // Active engine chip
                Rectangle {
                    height: 20
                    width: engineChipLbl.implicitWidth + 18
                    radius: 10
                    color: window && window.appSettings.orKey
                           ? Qt.rgba(0.95,0.62,0.07,0.14)
                           : Qt.rgba(0.49, 0.23, 0.93, 0.14)
                    border.color: window && window.appSettings.orKey
                           ? Qt.rgba(0.95,0.62,0.07,0.35)
                           : Qt.rgba(0.67, 0.55, 1.0, 0.32)
                    border.width: 1
                    Text {
                        id: engineChipLbl
                        anchors.centerIn: parent
                        text: window && window.appSettings.orKey
                              ? "⚡ " + orModels[aiPrefs.orModelIdx].label
                              : "☁ Claude"
                        font.pixelSize: 9; font.family: Theme.fontSans
                        color: window && window.appSettings.orKey ? "#F59E0B" : Theme.accent2
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Settings gear
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

        // ── Settings panel ───────────────────────────────────────────────
        Rectangle {
            id: settingsPanel
            visible: false
            Layout.fillWidth: true
            height: visible ? spCol.implicitHeight + 28 : 0
            clip: true
            radius: 16
            color: Theme.dark ? Qt.rgba(0.02,0.02,0.12,0.90) : Qt.rgba(0.93,0.96,1.0,0.95)
            border.color: Qt.rgba(0.49, 0.23, 0.93, 0.28); border.width: 1
            Behavior on height { NumberAnimation { duration: 240; easing.type: Easing.OutQuart } }

            Rectangle {
                anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.60; height: 1; y: 1; radius: 1
                color: Qt.rgba(1, 1, 1, 0.18)
            }

            ColumnLayout {
                id: spCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                spacing: 12

                // ══ OPENROUTER MODEL PICKER ═════════════════════════════
                Rectangle {
                    Layout.fillWidth: true
                    height: orPickerCol.implicitHeight + 20
                    radius: 12
                    color: Qt.rgba(0.95, 0.62, 0.07, 0.05)
                    border.color: Qt.rgba(0.95, 0.62, 0.07, 0.22); border.width: 1

                    Column {
                        id: orPickerCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                        spacing: 10

                        // Header
                        RowLayout {
                            width: parent.width
                            Text {
                                text: "⚡  OPENROUTER  ·  FREE MODELS"
                                font.pixelSize: 9; color: "#F59E0B"
                                font.letterSpacing: 1.2; font.weight: Font.Bold
                                font.family: Theme.fontSans
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                height: 16; width: freeLbl.implicitWidth + 12; radius: 8
                                color: Qt.rgba(0.95,0.62,0.07,0.12)
                                border.color: Qt.rgba(0.95,0.62,0.07,0.30); border.width: 1
                                Text { id: freeLbl; anchors.centerIn: parent; text: "no credit card"; font.pixelSize: 8; color: "#F59E0B" }
                            }
                        }

                        // Model selector pills
                        Flow {
                            width: parent.width
                            spacing: 6
                            Repeater {
                                model: orModels
                                delegate: Rectangle {
                                    height: 28
                                    width: modelPillLbl.implicitWidth + 20
                                    radius: 14
                                    color: aiPrefs.orModelIdx === index
                                           ? Qt.rgba(0.95,0.62,0.07,0.22)
                                           : Qt.rgba(1,1,1,0.06)
                                    border.color: aiPrefs.orModelIdx === index
                                           ? Qt.rgba(0.95,0.62,0.07,0.55)
                                           : Qt.rgba(1,1,1,0.14)
                                    border.width: 1
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 5
                                        Text {
                                            id: modelPillLbl
                                            text: modelData.label
                                            color: aiPrefs.orModelIdx === index ? "#F59E0B" : Theme.text2
                                            font.pixelSize: 10; font.family: Theme.fontSans
                                            font.weight: aiPrefs.orModelIdx === index ? Font.SemiBold : Font.Normal
                                        }
                                        Rectangle {
                                            width: badgeLbl.implicitWidth + 8; height: 14; radius: 7
                                            color: Qt.rgba(0.04,0.73,0.51,0.14)
                                            anchors.verticalCenter: parent.verticalCenter
                                            Text {
                                                id: badgeLbl
                                                anchors.centerIn: parent
                                                text: modelData.badge; font.pixelSize: 7; color: "#10B981"
                                            }
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: aiPrefs.orModelIdx = index
                                    }
                                }
                            }
                        }

                        // Selected model description
                        Text {
                            width: parent.width
                            text: orModels[aiPrefs.orModelIdx].desc
                            font.pixelSize: 9; color: Theme.text3; font.family: Theme.fontSans
                            wrapMode: Text.WordWrap
                        }

                        // Gemma local note
                        Rectangle {
                            width: parent.width
                            height: gemmaRow.implicitHeight + 12
                            radius: 9
                            color: Qt.rgba(0.12, 0.06, 0.28, 0.45)
                            border.color: Qt.rgba(0.49, 0.23, 0.93, 0.22); border.width: 1

                            RowLayout {
                                id: gemmaRow
                                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 10 }
                                spacing: 8
                                Text { text: "💎"; font.pixelSize: 14 }
                                Column {
                                    Layout.fillWidth: true; spacing: 2
                                    Text {
                                        text: "Gemma 3 1B  ·  local download also available"
                                        font.pixelSize: 9; color: "#A78BFA"; font.weight: Font.SemiBold
                                        font.family: Theme.fontSans
                                    }
                                    Text {
                                        width: parent.width
                                        text: "Enable local model in More → Local AI settings"
                                        font.pixelSize: 8; color: Theme.text3; font.family: Theme.fontSans
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }
                        }
                    }
                }

                // ══ OPENROUTER KEY ══════════════════════════════════════
                Text { text: "OPENROUTER KEY (free — get one at openrouter.ai)"; font.pixelSize: 8; color: "#7070a8"; font.letterSpacing: 1.2 }
                RowLayout { spacing: 8
                    StyledInput {
                        id: keyInput; Layout.fillWidth: true
                        placeholderText: "sk-or-v1-…"; echoMode: TextInput.Password
                        text: window ? window.appSettings.orKey : ""
                    }
                    Rectangle {
                        width: 64; height: 42; radius: 12
                        gradient: Gradient { orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#5B21B6" }
                            GradientStop { position: 1.0; color: "#7C3AED" } }
                        Text { anchors.centerIn: parent; text: "Save"; color: "#fff"; font.pixelSize: 12; font.weight: Font.Medium }
                        MouseArea { anchors.fill: parent; onClicked: {
                            if (window) window.appSettings.orKey = keyInput.text
                            settingsPanel.visible = false
                            root.window?.showToast("API key saved ✓", true)
                        }}
                    }
                }

                // ══ ANTHROPIC KEY ══════════════════════════════════════
                Text { text: "ANTHROPIC KEY (optional — vision fallback)"; font.pixelSize: 8; color: "#7070a8"; font.letterSpacing: 1.2 }
                RowLayout { spacing: 8
                    StyledInput {
                        id: anthKeyInput; Layout.fillWidth: true
                        placeholderText: "sk-ant-…"; echoMode: TextInput.Password
                        text: window ? window.appSettings.anthKey : ""
                    }
                    Rectangle {
                        width: 64; height: 42; radius: 12
                        gradient: Gradient { orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#0e6830" }
                            GradientStop { position: 1.0; color: "#10B981" } }
                        Text { anchors.centerIn: parent; text: "Save"; color: "#fff"; font.pixelSize: 12; font.weight: Font.Medium }
                        MouseArea { anchors.fill: parent; onClicked: {
                            if (window) window.appSettings.anthKey = anthKeyInput.text
                            settingsPanel.visible = false
                            root.window?.showToast("Anthropic key saved ✓", true)
                        }}
                    }
                }

                RowLayout {
                    visible: window && window.appSettings.orKey !== ""
                    spacing: 8
                    Rectangle { width: 8; height: 8; radius: 4; color: "#10B981"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "OpenRouter active · " + orModels[aiPrefs.orModelIdx].label; color: "#10B981"; font.pixelSize: 10; Layout.fillWidth: true }
                    Rectangle {
                        width: 58; height: 24; radius: 8
                        color: Qt.rgba(0.96,0.25,0.37,0.08); border.color: Qt.rgba(0.96,0.25,0.37,0.28); border.width: 1
                        Text { anchors.centerIn: parent; text: "Remove"; font.pixelSize: 9; color: "#F43F5E" }
                        MouseArea { anchors.fill: parent; onClicked: {
                            if(window) window.appSettings.orKey = ""; keyInput.text = "" }}
                    }
                }
            }
        }

        // ── Messages area ──────────────────────────────────────────────
        Flickable {
            id: msgFlickable
            Layout.fillWidth: true; Layout.fillHeight: true
            contentHeight: msgCol.implicitHeight + 16
            clip: true

            ColumnLayout {
                id: msgCol
                width: parent.width; spacing: 10

                // Empty state chips
                Column {
                    visible: messages.length === 0 && !loading
                    Layout.fillWidth: true; spacing: 6

                    Text {
                        text: "Try asking…"
                        font.pixelSize: 10; color: Theme.text3; font.family: Theme.fontSans
                        font.letterSpacing: 0.5; bottomPadding: 4
                    }

                    Repeater {
                        model: examples
                        delegate: Rectangle {
                            width: msgCol.width; height: 42; radius: 14
                            color: Theme.sectionBg; border.color: Theme.border1; border.width: 1
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                                Text { text: modelData.startsWith("📷") ? "📷" : "⚡"; font.pixelSize: 11; color: "#7C3AED" }
                                Text { Layout.fillWidth: true; text: modelData; color: Theme.text3; font.pixelSize: 12; font.family: Theme.fontSans; elide: Text.ElideRight }
                                Text { text: "›"; font.pixelSize: 14; color: Theme.text3 }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: { if (modelData.startsWith("📷")) filePicker.open(); else sendMessage(modelData) }
                            }
                        }
                    }
                }

                // Message bubbles
                Repeater {
                    model: messages
                    delegate: ColumnLayout {
                        width: parent.width; spacing: 4
                        opacity: 0; y: 14
                        Component.onCompleted: { opacity = 1; y = 0 }
                        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on y      { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                        // User bubble
                        Column {
                            visible: modelData.role === "user"
                            Layout.alignment: Qt.AlignRight
                            Layout.maximumWidth: parent.width * 0.85
                            spacing: 4

                            Rectangle {
                                visible: modelData.hasAttachment && modelData.attachMime && modelData.attachMime.startsWith("image/")
                                width: 140; height: 100; radius: 12
                                color: Qt.rgba(1,1,1,0.05); border.color: Qt.rgba(1,1,1,0.12); border.width: 1
                                anchors.right: parent.right
                                Text { anchors.centerIn: parent; text: "🖼 " + (modelData.attachName || "image")
                                    font.pixelSize: 11; color: Theme.text2; wrapMode: Text.WordWrap; width: parent.width - 16; horizontalAlignment: Text.AlignHCenter }
                            }
                            Rectangle {
                                visible: modelData.hasAttachment && modelData.attachMime && !modelData.attachMime.startsWith("image/")
                                height: 28; width: pdfLbl.implicitWidth + 28; radius: 10; anchors.right: parent.right
                                color: Qt.rgba(0.95,0.62,0.07,0.12); border.color: Qt.rgba(0.95,0.62,0.07,0.30); border.width: 1
                                Text { id: pdfLbl; anchors.centerIn: parent; text: "📄 " + (modelData.attachName || "file"); font.pixelSize: 10; color: "#F59E0B" }
                            }

                            Rectangle {
                                Layout.alignment: Qt.AlignRight
                                width: Math.min(uTxt.implicitWidth + 28, msgCol.width * 0.82)
                                height: uTxt.implicitHeight + 22
                                anchors.right: parent.right
                                radius: 18; topRightRadius: 5
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: Qt.rgba(0.36,0.23,0.93,0.32) }
                                    GradientStop { position: 1.0; color: Qt.rgba(0.49,0.23,0.93,0.28) }
                                }
                                border.color: Qt.rgba(0.67,0.55,1.0,0.38); border.width: 1
                                Text { id: uTxt; anchors.fill: parent; anchors.margins: 13
                                    text: modelData.content || ""; color: Theme.text; font.pixelSize: 13; wrapMode: Text.WordWrap }
                            }
                            Text { anchors.right: parent.right; text: modelData.time || ""; font.pixelSize: 9; color: Theme.text3; rightPadding: 4 }
                        }

                        // Assistant bubble
                        Rectangle {
                            visible: modelData.role === "assistant"
                            Layout.fillWidth: true
                            height: aCol.implicitHeight + 24
                            radius: 18; topLeftRadius: 5
                            color: modelData.isError ? Qt.rgba(0.96,0.25,0.37,0.06) : Qt.rgba(1,1,1,0.055)
                            border.color: modelData.isError ? Qt.rgba(0.96,0.25,0.37,0.30) : Qt.rgba(1,1,1,0.12)
                            border.width: 1

                            Rectangle {
                                anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width * 0.55; height: 1; y: 1; radius: 1
                                color: Qt.rgba(1,1,1, modelData.isError ? 0.06 : 0.10)
                            }

                            ColumnLayout {
                                id: aCol
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                                spacing: 7

                                // Engine badge + model + time + copy
                                RowLayout { spacing: 6
                                    Rectangle {
                                        height: 20; radius: 10; width: eBadge.implicitWidth + 16
                                        color: modelData.engine === "offline"    ? Qt.rgba(0.06,0.73,0.51,0.12)
                                             : modelData.engine === "openrouter" ? Qt.rgba(0.95,0.62,0.07,0.12)
                                             : Qt.rgba(0.49,0.23,0.93,0.12)
                                        border.color: modelData.engine === "offline"    ? Qt.rgba(0.06,0.73,0.51,0.35)
                                                    : modelData.engine === "openrouter" ? Qt.rgba(0.95,0.62,0.07,0.35)
                                                    : Qt.rgba(0.49,0.23,0.93,0.30)
                                        border.width: 1
                                        Text {
                                            id: eBadge; anchors.centerIn: parent
                                            text: modelData.engine === "offline"    ? "⚡ offline"
                                                : modelData.engine === "openrouter" ? "⚡ " + (modelData.model || "openrouter")
                                                : "☁ claude"
                                            font.pixelSize: 9; font.family: Theme.fontSans
                                            color: modelData.engine === "offline"    ? "#10B981"
                                                 : modelData.engine === "openrouter" ? "#F59E0B"
                                                 : "#A78BFA"
                                        }
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text { text: modelData.time || ""; font.pixelSize: 9; color: Theme.text3 }

                                    // Copy button
                                    Rectangle {
                                        width: 22; height: 22; radius: 7
                                        color: copyMa.containsMouse ? Qt.rgba(1,1,1,0.10) : "transparent"
                                        border.color: Qt.rgba(1,1,1,0.10); border.width: 1
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                        Text { anchors.centerIn: parent; text: "⎘"; font.pixelSize: 10; color: Theme.text3 }
                                        MouseArea {
                                            id: copyMa; anchors.fill: parent; hoverEnabled: true
                                            onClicked: root.window?.showToast("Copied!", true)
                                        }
                                    }
                                }

                                Text {
                                    text: modelData.content || ""
                                    color: modelData.isError ? "#FDA4AF" : "#f0f0ff"
                                    font.pixelSize: 16; font.weight: Font.Light
                                    wrapMode: Text.WordWrap; Layout.fillWidth: true
                                }

                                // Math expression block
                                Rectangle {
                                    visible: (modelData.expr || "") !== ""
                                    Layout.fillWidth: true
                                    height: exprTxt.implicitHeight + 14
                                    radius: 10
                                    color: Qt.rgba(0.49,0.23,0.93,0.08)
                                    border.color: Qt.rgba(0.49,0.23,0.93,0.22); border.width: 1
                                    Text {
                                        id: exprTxt
                                        anchors { fill: parent; margins: 12; topMargin: 7; bottomMargin: 7 }
                                        text: modelData.expr || ""
                                        color: Theme.accent2; font.pixelSize: 11; font.family: Theme.fontMono
                                        wrapMode: Text.WordWrap
                                    }
                                }

                                // Steps
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
                                                Text { anchors.centerIn: parent; text: index+1; font.pixelSize: 9; color: "#06B6D4"; font.weight: Font.Bold }
                                            }
                                            Text {
                                                text: modelData; Layout.fillWidth: true
                                                color: "#9090cc"; font.pixelSize: 11; font.family: Theme.fontMono
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
                                    color: Qt.rgba(0.06,0.73,0.51,0.09); border.color: Qt.rgba(0.06,0.73,0.51,0.28); border.width: 1
                                    Text { id: noteTxt; anchors.centerIn: parent; text: "ⓘ " + (modelData.note||""); color: "#10B981"; font.pixelSize: 10 }
                                }
                            }
                        }
                    }
                }

                // Typing dots
                Rectangle {
                    visible: loading
                    Layout.fillWidth: true; height: 52; radius: 18; topLeftRadius: 5
                    color: Theme.sectionBg; border.color: Theme.border2; border.width: 1
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
                        Text {
                            text: "  Thinking…"
                            color: Theme.text3; font.pixelSize: 12; leftPadding: 2
                        }
                    }
                }

                Item { height: 4 }
            }
        }

        // ── Attachment preview strip ───────────────────────────────────
        Rectangle {
            visible: attachedBase64 !== ""
            Layout.fillWidth: true
            height: visible ? 52 : 0; clip: true; radius: 12
            color: Qt.rgba(0.49,0.23,0.93,0.08)
            border.color: Qt.rgba(0.49,0.23,0.93,0.28); border.width: 1
            Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            RowLayout {
                anchors.fill: parent; anchors.margins: 10; spacing: 10
                Text { text: attachedIsImage ? "🖼" : "📄"; font.pixelSize: 22 }
                Column {
                    Layout.fillWidth: true; spacing: 2
                    Text { text: attachedFileName; font.pixelSize: 12; color: Theme.text; font.family: Theme.fontSans; elide: Text.ElideRight; width: parent.width }
                    Text { text: attachedMime + " · " + fileHelper.humanSize(attachedFileUrl); font.pixelSize: 9; color: Theme.text3 }
                }
                Rectangle {
                    width: 28; height: 28; radius: 8
                    color: Qt.rgba(0.96,0.25,0.37,0.10); border.color: Qt.rgba(0.96,0.25,0.37,0.30); border.width: 1
                    Text { anchors.centerIn: parent; text: "×"; color: "#F43F5E"; font.pixelSize: 14; font.weight: Font.Bold }
                    MouseArea { anchors.fill: parent; onClicked: clearAttachment() }
                }
            }
        }

        // ── Input row ──────────────────────────────────────────────────
        RowLayout { Layout.fillWidth: true; spacing: 8

            Rectangle {
                width: 46; height: 46; radius: 14
                color: attachedBase64 !== "" ? Qt.rgba(0.49,0.23,0.93,0.22) : Qt.rgba(1,1,1,0.06)
                border.color: attachedBase64 !== "" ? Qt.rgba(0.67,0.55,1.0,0.45) : Qt.rgba(1,1,1,0.12); border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }
                Text { anchors.centerIn: parent; text: "📎"; font.pixelSize: 18 }
                MouseArea { anchors.fill: parent; onClicked: filePicker.open() }
            }

            Rectangle {
                Layout.fillWidth: true
                height: Math.min(inputTA.implicitHeight + 4, 120)
                radius: 16; color: Theme.sectionBg
                border.color: inputTA.activeFocus ? Qt.rgba(0.49,0.23,0.93,0.65) : Qt.rgba(1,1,1,0.12)
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 150 } }

                TextArea {
                    id: inputTA
                    anchors.fill: parent; anchors.margins: 12
                    text: inputText
                    placeholderText: attachedBase64 !== "" ? "Ask about the attached file…" : "Ask anything…"
                    color: Theme.text; placeholderTextColor: "#44446a"
                    font.pixelSize: 14; font.family: Theme.fontSans
                    wrapMode: Text.WordWrap; background: null
                    onTextChanged: inputText = text
                    Keys.onReturnPressed: function(e) {
                        if (!(e.modifiers & Qt.ShiftModifier)) { e.accepted = true; sendMessage() }
                    }
                }
            }

            Rectangle {
                width: 46; height: 46; radius: 14
                enabled: !loading && (inputText.trim() !== "" || attachedBase64 !== "")
                opacity: enabled ? 1.0 : 0.35
                Behavior on opacity { NumberAnimation { duration: 120 } }

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: enabled ? "#5B21B6" : Qt.rgba(1,1,1,0.06) }
                    GradientStop { position: 1.0; color: enabled ? "#06B6D4" : Qt.rgba(1,1,1,0.06) }
                }
                border.color: enabled ? "transparent" : Qt.rgba(1,1,1,0.12); border.width: 1

                scale: sendMa.pressed ? 0.88 : 1.0
                Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }

                Text { anchors.centerIn: parent; text: "↑"; color: "#fff"; font.pixelSize: 20; font.weight: Font.Bold }
                MouseArea { id: sendMa; anchors.fill: parent; enabled: parent.enabled; onClicked: sendMessage() }
            }
        }

        // ── Footer ─────────────────────────────────────────────────────
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
                font.pixelSize: 9; color: Theme.text3
            }
        }
    }

    Timer { id: scrollTimer; interval: 50
        onTriggered: msgFlickable.contentY = Math.max(0, msgFlickable.contentHeight - msgFlickable.height) }
}
