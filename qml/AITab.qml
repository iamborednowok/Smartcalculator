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

    // ── Entrance animation (plays each time this tab becomes current) ──
    // A quick fade + gentle pop-in on switching to this tab instead of
    // just snapping into view — see Theme.popDuration/popEasing.
    opacity: 1.0
    scale: 1.0
    // Driven from Main.qml — see GraphTab.qml for why this is no longer
    // StackLayout.isCurrentItem (this tab is now lazy-loaded via Loader).
    // Also now doubles as the signal for whether a reply that arrives
    // while the user is elsewhere should raise a toast — see
    // handleResponse() below.
    property bool isCurrentTab: false
    onIsCurrentTabChanged: if (isCurrentTab) { enterFade.restart(); enterScale.restart() }
    NumberAnimation { id: enterFade;  target: root; property: "opacity"; from: 0.0;  to: 1.0; duration: Theme.popDuration; easing.type: Easing.OutQuad }
    NumberAnimation { id: enterScale; target: root; property: "scale";   from: 0.97; to: 1.0; duration: Theme.popDuration; easing.type: Theme.popEasing; easing.overshoot: Theme.popOvershoot }

    // FileHelper is local to this tab (only AITab needs it — matches
    // FileHelper.h's own doc comment: "Instantiate once in AITab").
    FileHelper { id: fileHelper }

    // ── AI skills registry ────────────────────────────────────────────
    // ai-skills/skillviewer.md is bundled into the binary as a Qt
    // resource (see CMakeLists.txt) and read here once, when this tab is
    // created — it's Loader-instantiated (see isCurrentTab above), so
    // Component.onCompleted already only fires when someone opens the AI
    // tab, i.e. right as a conversation starts. Cached in
    // skillsPromptText and reused by every sendMessage() call in this
    // session rather than re-read per turn.
    //
    // This doesn't mean the model reads the file — it still can't;
    // skillviewer.md's own "How a model actually sees this file" section
    // is still accurate about that. What changed is *who* reads it:
    // previously a person hand-copied a terse version of it into the
    // SKILLS block in sendMessage(), and the two could quietly drift
    // apart. Now the app reads the real file at runtime and that text —
    // not a retyped copy — is what gets folded into systemPrompt. Same
    // one-shot-HTTP-request mechanics as before, just sourced from the
    // file instead of duplicated by hand.
    //
    // Only the "## Skills" section is pulled out (extractSkillsSection()
    // grabs everything between the "## Skills" heading and the next
    // "## " one). The rest of the file — its own preamble, "Keeping this
    // in sync", "Considered and skipped" — is written for whoever's
    // maintaining the registry, not for the model answering a question:
    // sending all of it would roughly double the whole systemPrompt's
    // size on every single turn (~2,570 vs. ~300 tokens for the old
    // mirror; the "## Skills"-only extract lands around ~1,300) for
    // content the model has no use for, and one part of it — this file
    // explaining that the model can't read files — would be a strange
    // thing to have the model read about itself.
    property string skillsPromptText: ""
    Component.onCompleted: {
        skillsPromptText = loadSkillsPromptText()
        messages = loadPersistedChat()
    }

    // Restores whatever appendMsg() last saved to chatHistoryPath, so a
    // closed and reopened app shows the same conversation instead of an
    // empty one — messages was pure in-memory state before this. Returns
    // [] (never throws, never leaves messages undefined) on every failure
    // path: no file yet (first run — readTextFile already returns "" for
    // that), corrupt JSON (hand-edited or truncated by a crash mid-write),
    // or a saved shape that is not actually an array. A chat feature
    // should not be able to crash the app it is bolted onto.
    function loadPersistedChat() {
        var raw = fileHelper.readTextFile(chatHistoryPath)
        if (!raw) return []
        try {
            var restored = JSON.parse(raw)
            return Array.isArray(restored) ? restored : []
        } catch (e) {
            return []
        }
    }

    // Pulls the "## Skills" … (next "## " heading) span out of a
    // skillviewer.md-shaped markdown string. Plain substring search, not
    // a markdown parser — deliberately: this only ever runs against one
    // known file whose heading shape is easy to keep stable, and a real
    // parser would be a lot of weight for one extraction.
    function extractSkillsSection(md) {
        if (!md) return ""
        var startMarker = "## Skills"
        var start = md.indexOf(startMarker)
        if (start === -1) return ""
        var rest = md.slice(start + startMarker.length)
        var stop = rest.search(/\n##\s/)
        return (stop === -1 ? rest : rest.slice(0, stop)).trim()
    }

    // Loads + extracts the registry text, falling back to the previous
    // hand-kept bullets if the resource can't be read or its headings
    // ever change shape — so a build or bundling problem degrades to
    // "skills work with slightly stale docs" rather than "no SKILLS text
    // reaches the model at all". If you rename the "## Skills" heading in
    // skillviewer.md, update this fallback in the same change, same
    // reasoning as keeping skillviewer.md and this block in sync used to
    // require — this just moves *where* the sync risk lives, from
    // "systemPrompt vs. skillviewer.md" to "this fallback vs.
    // skillviewer.md's heading text", and only bites if the file can't be
    // read at all.
    function loadSkillsPromptText() {
        var raw = fileHelper.readTextFile("qrc:/ai-skills/skillviewer.md")
        var section = extractSkillsSection(raw)
        if (section) return section
        return '- plot_graph: see/plot/graph a function of x. '
            + 'params: {"expressions":["f(x) form, e.g. sin(x), x^2-4, 1/x"], up to 4}.\n'
            + '- evaluate_expression: verify an arithmetic or formula result — percentages, interest, geometry, anything with real numbers in it. '
            + 'params: {"expression":"calculator-syntax expression, e.g. 1000*(1+0.07/12)^(12*20)"}.\n'
            + '- convert_units: convert a value between units. '
            + 'params: {"value":number,"from":"unit","to":"unit","category":"Length|Weight|Temperature|Speed|Volume|Time|Data"}. '
            + 'Units must match exactly — Length: mm/cm/m/km/in/ft/yd/mi, Weight: g/kg/lb/oz/t, Temperature: °C/°F/K, '
            + 'Speed: m/s/km/h/mph/knot, Volume: ml/l/"fl oz"/cup/pt/gal, Time: s/min/hr/day/wk/mo/yr, Data: B/KB/MB/GB/TB/PB.\n'
            + '- roll_random: dice, a coin flip, or a random number in a range. '
            + 'params: {"kind":"dice","sides":6,"count":1} or {"kind":"coin"} or {"kind":"range","min":1,"max":100}.\n'
            + '- convert_base: show a number in decimal/hex/octal/binary. '
            + 'params: {"value":"string as typed","fromBase":10,"bitWidth":32} — fromBase/bitWidth optional, default 10 and 32.'
    }

    // Small standalone persisted pref — doesn't need the full AppSettings
    // round-trip for a single int, so it keeps its own Qt.labs.settings store.
    Settings {
        id: aiPrefs
        category: "AITabV80"
        property int orModelIdx: 0
    }

    // Verified directly against openrouter.ai's live free-models catalog
    // (July 2026) — free model lineups rotate as providers add/retire
    // capacity, so this list *will* go stale again eventually the same
    // way the old Llama 3.3 / Gemma 3 / Mistral 7B one did (Mistral in
    // particular currently has zero free models on OpenRouter at all).
    // "Auto (Free)" is the default (index 0) specifically because it
    // doesn't rot the same way — it re-resolves to whatever's actually
    // available every request instead of pointing at one fixed slug.
    //
    // Deliberately NOT openrouter/auto: that router's candidate set
    // includes paid models and can silently bill the account behind
    // whichever key is active. openrouter/free is OpenRouter's own
    // zero-cost-guaranteed router — same convenience, no billing risk.
    readonly property var orModels: [
        { id: "openrouter/free",                       label: "Auto (Free)",      desc: "OpenRouter picks a free model for you — zero-cost guaranteed, never bills" },
        { id: "tencent/hy3:free",                       label: "Hy3",              desc: "Tencent — OpenRouter's highest-traffic free model right now, strong all-round reasoning" },
        { id: "nvidia/nemotron-3-super-120b-a12b:free", label: "Nemotron 3 Super", desc: "NVIDIA — 1M context, built for multi-step reasoning" },
        { id: "nvidia/nemotron-3-nano-30b-a3b:free",    label: "Nemotron 3 Nano",  desc: "NVIDIA — smaller & faster, good for quick answers" },
    ]

    // ── State ──────────────────────────────────────────────────────────
    property var    messages:  []
    property bool   loading:   false
    property string inputText: ""

    // Agent-loop state — see "Agent loop" section above sendMessage() for
    // the full explanation. loopStep is 1-based once a loop is underway
    // and reset to 0 the moment a reply finishes without asking to
    // continue (which is most replies), so it doubles as "is a loop
    // currently in progress" (loopStep > 0) without a separate flag.
    property var loopApiMsgs: []
    property int loopStep: 0
    // Hard ceiling on rounds per user message regardless of what the model
    // wants — a free/small model insisting "done":false forever would
    // otherwise turn one question into an unbounded chain of calls. 4
    // gives real headroom (propose+act, react+act again, react+act a third
    // time, forced final) without that risk.
    readonly property int maxLoopSteps: 4

    // Local chat-history persistence — see loadPersistedChat()/appendMsg()
    // below. Resolved once via FileHelper::appDataPath(), which puts this
    // at the platform-correct writable app-data directory (e.g.
    // ~/.local/share/SmartCalc/ai_chat_history.json on Linux) — same
    // QStandardPaths::AppDataLocation main.cpp's crash log already uses,
    // just a different filename in the same directory.
    readonly property string chatHistoryPath: fileHelper.appDataPath("ai_chat_history.json")

    // ── Easter eggs / secret game ────────────────────────────────────
    property bool showSnakeGame: false
    property bool showBossFight: false

    // Brian's conversation state — "off" outside of talking to him.
    // "greeted"   — just said "You want to meet the boss?", waiting on yes/no
    // "listening" — asked "something important to discuss", waiting on a reply
    // "dared"     — issued the dare after an insult, waiting on confirm/back-down
    property string brianMode: "off"

    // Returns a short id string for a recognized secret phrase, or ""
    // for anything else — checked against the trimmed, lowercased input
    // so "Snake", "snake", " snake " all match the same way. Exact
    // matches only, deliberately: substring matching ("contains snake")
    // would misfire on a genuine question that happens to mention one of
    // these words.
    function checkSecretTrigger(text) {
        var t = text.trim().toLowerCase()
        if (t === "snake" || t === "play snake" || t === "secret game") return "snake"
        if (t === "brian") return "brian"
        if (t === "are you sentient" || t === "are you alive" || t === "are you conscious") return "sentient"
        if (t === "hello world") return "helloworld"
        if (t === "42") return "42"
        return ""
    }

    // Appends an assistant bubble that did not come from a model call —
    // every field the real path fills in (think/steps/expr/note/skill
    // results) just gets its empty default, and "model" is set to a
    // visibly-different label so it never looks like an actual AI reply
    // that happened to be instant.
    function appendLocalReply(text) {
        appendMsg({
            role: "assistant", content: text, model: "🥚 secret", time: Qt.formatTime(new Date(), "hh:mm"),
            think: "", steps: [], expr: "", note: "",
            graphExprs: [], evalResult: null, convertResult: null, rollResult: null, baseResult: null,
            isError: false
        })
    }

    // Same as appendLocalReply, distinct label — Brian is a character
    // with his own voice, not the generic "🥚 secret" narrator the other
    // Easter eggs use, so his lines should read as *his*, not the app's.
    function appendBrianReply(text) {
        appendMsg({
            role: "assistant", content: text, model: "🧠 Brian", time: Qt.formatTime(new Date(), "hh:mm"),
            think: "", steps: [], expr: "", note: "",
            graphExprs: [], evalResult: null, convertResult: null, rollResult: null, baseResult: null,
            isError: false
        })
    }

    // ── Brian's keyword matching ──────────────────────────────────────
    // Deliberately loose (substring, not exact) once inside a conversation
    // with him — unlike checkSecretTrigger's entry points above, which stay
    // exact-match to avoid misfiring on a genuine question. The tradeoff is
    // reversed here on purpose: you only reach these checks after already
    // typing the literal word "brian" and then "Yes." to a very on-the-nose
    // prompt, so the context is already narrow and deliberate — a full
    // parser isn't in scope, but simple keyword matching is a reasonable
    // stand-in for "did the user mean roughly this" inside that context.
    function containsAny(text, words) {
        var t = text.toLowerCase()
        for (var i = 0; i < words.length; i++) if (t.indexOf(words[i]) !== -1) return true
        return false
    }
    function isAffirmative(text) {
        return containsAny(text, ["yes", "yeah", "yep", "yup", "sure", "ok", "okay", "definitely", "of course"])
    }
    function isInsult(text) {
        return containsAny(text, ["evil", "stupid", "dumb", "idiot", "hate you", "you suck", "worst",
                                    "trash", "garbage", "loser", "useless", "pathetic", "terrible"])
    }
    function isConfirmDefiance(text) {
        return isInsult(text) || containsAny(text, ["mean it", "i do", "again", "for real", "i said it", "yeah i"])
    }
    // Tab index mapping mirrors Main.qml's StackLayout order exactly (see
    // its own comment: "index — must match StackLayout child order").
    // 0 Calc, 1 Formula, 2 Convert, 3 Random, 4 Graph, 5 Programmer, 6 AI —
    // 6 is deliberately unreachable here since asking Brian to send you to
    // the tab you are already talking to him in would not do anything.
    function matchTabRequest(text) {
        var t = text.toLowerCase()
        var wantsAction = containsAny(t, ["switch", "go to", "open", "take me", "change to", "back to"])
        if (!wantsAction) return -1
        if (t.indexOf("calc") !== -1) return 0
        if (t.indexOf("formula") !== -1) return 1
        if (t.indexOf("convert") !== -1) return 2
        if (t.indexOf("random") !== -1 || t.indexOf("dice") !== -1) return 3
        if (t.indexOf("graph") !== -1) return 4
        if (t.indexOf("programmer") !== -1 || t.indexOf("binary") !== -1) return 5
        return -1
    }
    function matchSnakeRequest(text) {
        return text.toLowerCase().indexOf("snake") !== -1
    }

    // The state machine itself. Called instead of the normal send path
    // (see sendMessage()) for every message while brianMode !== "off" —
    // echoes the user's line first so the conversation reads normally,
    // then advances (or ends) the conversation based on which state we're
    // in. Every exit path sets brianMode back to "off" except the one
    // that continues into "dared".
    function handleBrianReply(userText) {
        appendMsg({
            role: "user", content: userText, time: Qt.formatTime(new Date(), "hh:mm"),
            hasAttachment: false, attachName: ""
        })

        if (brianMode === "greeted") {
            if (isAffirmative(userText)) {
                brianMode = "listening"
                appendBrianReply("Do you have something important to discuss with me?")
            } else {
                brianMode = "off"
                appendBrianReply("Suit yourself.")
            }
            return
        }

        if (brianMode === "listening") {
            var tabIdx = matchTabRequest(userText)
            if (tabIdx !== -1) {
                appendBrianReply("Just this once.")
                if (window) window.currentTab = tabIdx
                brianMode = "off"
                return
            }
            if (matchSnakeRequest(userText)) {
                appendBrianReply("Just this once.")
                showSnakeGame = true
                brianMode = "off"
                return
            }
            if (isInsult(userText)) {
                brianMode = "dared"
                appendBrianReply("Say that thing again, I dare you.")
                return
            }
            brianMode = "off"
            appendBrianReply("Nonsense, get lost.")
            return
        }

        if (brianMode === "dared") {
            brianMode = "off"
            if (isConfirmDefiance(userText)) {
                appendBrianReply("You will not survive 👹👹👹")
                showBossFight = true
            } else {
                appendBrianReply("Nonsense, get lost.")
            }
            return
        }

        // Defensive fallback — should be unreachable (every state above
        // returns), but if brianMode is ever some unexpected value, do not
        // strand the conversation there silently.
        brianMode = "off"
    }
    property string attachedBase64:   ""
    property string attachedMime:     ""
    property string attachedFileName: ""
    property bool   attachedIsImage:  false

    property bool settingsOpen: false

    FileDialog {
        id: filePicker
        title: "Attach image or PDF"
        nameFilters: ["Images (*.jpg *.jpeg *.png *.webp *.gif)", "PDF files (*.pdf)", "All files (*)"]
        onAccepted: {
            var url  = selectedFile.toString()
            var mime = fileHelper.mimeTypeForFile(url)
            var b64  = fileHelper.readFileAsBase64(url)
            if (b64 === "") { root.window?.showToast("Could not read file", false); return }
            attachedFileUrl  = url
            attachedBase64   = b64
            attachedMime     = mime
            attachedFileName = fileHelper.fileName(url)
            attachedIsImage  = mime.startsWith("image/")
            root.window?.showToast("Attached: " + attachedFileName, true)
        }
    }

    // ── Helpers ────────────────────────────────────────────────────────
    function handleResponse(content, isError) {
        loading = false
        var parsed = tryParseJson(content)
        var time   = Qt.formatTime(new Date(), "hh:mm")

        // Computed once, up front — reused for this step's SkillResultCard
        // fields (same five fields as before) *and*, if the loop below
        // decides to continue, for the plain-text result summary sent back
        // to the model as its next input. One computation, two consumers.
        var gExprs  = parsed ? extractGraphExprs(parsed)    : []
        var eResult = parsed ? extractEvalResult(parsed)    : null
        var cResult = parsed ? extractConvertResult(parsed) : null
        var rResult = parsed ? extractRollResult(parsed)    : null
        var bResult = parsed ? extractBaseResult(parsed)    : null

        // loopStep is only ever > 1 once an earlier round of *this*
        // exchange already decided to continue (see the bottom of this
        // function) — so an ordinary, non-looping reply (the common case)
        // never carries this tag and renders exactly as it did before.
        var stepTag = loopStep > 1 ? (" · step " + loopStep) : ""

        appendMsg({
            role:          "assistant",
            content:       parsed ? parsed.answer : content,
            model:         (settings.orKey ? orModels[aiPrefs.orModelIdx].label : "Claude") + stepTag,
            time:          time,
            think:         parsed ? (parsed.think || "") : "",
            steps:         parsed ? (parsed.steps || []) : [],
            expr:          parsed ? (parsed.expression || "") : "",
            note:          parsed ? (parsed.note || "") : "",
            graphExprs:    gExprs,
            evalResult:    eResult,
            convertResult: cResult,
            rollResult:    rResult,
            baseResult:    bResult,
            isError:       isError
        })
        // BUG FIX: Main.qml used to only call handleResponse() while this
        // tab was current, so asking something and switching tabs before
        // the reply arrived silently dropped it — `loading` never cleared,
        // wedging the Send button (disabled while loading) permanently,
        // and the answer never appeared even when the user came back.
        // Responses are now always delivered (see Main.qml); a toast here
        // covers the "I've navigated away" case so the reply isn't
        // silently sitting in the chat history unannounced.
        if (!root.isCurrentTab && root.window)
            root.window.showToast(isError ? "AI reply had an error" : "AI replied", !isError)

        // An error or unparseable reply can't drive another round either
        // way — nothing to read a "done"/"actions" decision from — so
        // whatever loop might have been running ends here.
        if (isError || !parsed) { loopStep = 0; loopApiMsgs = []; return }

        // ── Agent loop continuation ─────────────────────────────────────
        var step = computeContinuation(parsed, gExprs, eResult, cResult, rResult, bResult, loopStep, maxLoopSteps)
        if (!step.doContinue) { loopStep = 0; loopApiMsgs = []; return }

        loopStep += 1
        loopApiMsgs = loopApiMsgs.concat([
            { role: "assistant", content: parsed.answer || "" },
            { role: "user", content: "Real result of your last action(s):\n" + step.resultLines.join("\n")
                + "\n\nContinue. Reply in the same JSON format; set \"done\":true once your answer is complete." }
        ])
        loading = true
        var mc = currentModelChoice()
        apiClient.sendToAI(buildSystemPrompt(), loopApiMsgs, mc.orKey, settings.anthKey, mc.geminiKey, mc.model)
    }

    // Whether a reply should continue into another round, and what to tell
    // the model about what actually happened if so. Pure — no appendMsg,
    // no apiClient, nothing QML-specific — on purpose: this is the one
    // piece of the loop with real edge cases, so it's written to be
    // checked against plain inputs/outputs rather than only read.
    //
    // Rules, in order:
    // 1. No parsed JSON at all — nothing to read a decision from, stop.
    // 2. done !== false — the model did not ask to continue. A model that
    //    never emits "done" at all (ignores the field, or predates it)
    //    gets exactly the old single-step behavior automatically: silence
    //    on a new field defaults to stopping, not to looping.
    // 3. No actions proposed — nothing for the app to have computed, so
    //    there is no real result to hand back; calling the model again
    //    would add a request without adding information.
    // 4. Step cap — hard stop regardless of what the model wants, so a
    //    model that keeps saying done:false cannot turn one question into
    //    an unbounded chain of calls.
    // 5. Every matching extractX() came back null/empty (bad params the
    //    model hallucinated) — same as #3, nothing real to report.
    function computeContinuation(parsed, gExprs, eResult, cResult, rResult, bResult, loopStepNow, cap) {
        if (!parsed) return { doContinue: false, resultLines: [] }
        var hasActions = Array.isArray(parsed.actions) && parsed.actions.length > 0
        var wantsMore  = parsed.done === false
        if (!hasActions || !wantsMore || loopStepNow >= cap) return { doContinue: false, resultLines: [] }

        var lines = []
        var askedPlot = parsed.actions.some(function(a) { return a && a.skill === "plot_graph" })
        if (askedPlot) {
            lines.push(gExprs.length
                ? "plot_graph: plotted " + gExprs.join(", ")
                : "plot_graph: none of those expressions could be evaluated")
        }
        if (eResult) lines.push("evaluate_expression: " + eResult.title + " = " + eResult.value)
        if (cResult) lines.push("convert_units: " + cResult.title + " = " + cResult.value)
        if (rResult) lines.push("roll_random: " + rResult.title + ": " + rResult.value)
        if (bResult) lines.push("convert_base: " + bResult.rows.map(function(r) { return r.label + "=" + r.value }).join(", "))

        if (lines.length === 0) return { doContinue: false, resultLines: [] }
        return { doContinue: true, resultLines: lines }
    }

    // { orKey, geminiKey, model } for whichever backend is currently
    // configured — the same choice sendMessage() always made, factored out
    // because the loop continuation above needs to make it again for
    // round 2+ without duplicating the provider/model-id logic a second
    // time. anthKey itself is not part of this return value (both call
    // sites still read settings.anthKey directly) since, unlike orKey and
    // geminiKey, nothing here ever needs to pick a *model id* to go with
    // it — the Anthropic branch's model id is fixed either way.
    function currentModelChoice() {
        var orKey     = settings.orKey
        var geminiKey = settings.geminiKey
        // Priority mirrors ApiClient::sendToAI exactly: OpenRouter's free
        // lineup first, then Gemini (also a genuine free tier, via Google
        // AI Studio), then the Anthropic fallback. Keep these two in sync
        // if that priority ever changes — there is no single shared source
        // for it between C++ and QML, just the same ordering written twice.
        var model
        if (orKey)          model = orModels[aiPrefs.orModelIdx].id
        else if (geminiKey) model = "gemini-3.5-flash"
        // QOL FIX: was the dated "claude-sonnet-4-20250514" snapshot —
        // several generations behind. claude-sonnet-5 is the current
        // model ID (dateless — Anthropic's 4.6+ generation IDs are
        // pinned snapshots by name, not by an appended date).
        else                model = "claude-sonnet-5"
        // BUG FIX: previously only orKey was passed through, so the direct-
        // Anthropic fallback (when no OpenRouter key is set) had no key to
        // actually authenticate with — see ApiClient::sendToAI. All keys
        // still need to travel together through every caller of this
        // (sendMessage's round 1, and the loop continuation in
        // handleResponse), which is exactly why this got pulled into one
        // function instead of staying inline in sendMessage alone.
        return { orKey: orKey, geminiKey: geminiKey, model: model }
    }

    function tryParseJson(raw) {
        try { return JSON.parse(raw.replace(/```json|```/g, "").trim()) }
        catch(e) { return null }
    }

    // ── Skill dispatch ─────────────────────────────────────────────────
    // Same probe technique GraphTab.addFunction() uses: a function like
    // sqrt(x-2) is legitimately NaN at x=1 but fine for x>=2, so "invalid"
    // means every probe failed, not just some. This is the actual gate on
    // whether the model's proposed expression is real math or a
    // hallucinated string — mathEngine.evaluateAt is the same sandboxed
    // evaluator GraphTab uses, so nothing from the model's output is ever
    // eval()'d directly.
    function isPlottable(expr) {
        var probeXs = [-5, -2, -1, 0, 1, 2, 5]
        for (var i = 0; i < probeXs.length; i++) {
            var v = mathEngine.evaluateAt(expr, probeXs[i])
            if (isFinite(v) && !isNaN(v)) return true
        }
        return false
    }

    // Pulls every plot_graph action's expressions out of parsed.actions,
    // flattens them (a reply could in principle carry more than one
    // plot_graph entry, though the system prompt only asks for one),
    // then filters to non-empty strings that actually evaluate somewhere
    // and caps at 4 — matches MiniGraphPlot's legend width and keeps the
    // preview legible at chat-bubble size.
    function extractGraphExprs(parsed) {
        if (!parsed || !Array.isArray(parsed.actions)) return []
        var exprs = []
        for (var i = 0; i < parsed.actions.length; i++) {
            var a = parsed.actions[i]
            if (a && a.skill === "plot_graph" && a.params && Array.isArray(a.params.expressions))
                exprs = exprs.concat(a.params.expressions)
        }
        return exprs
            .filter(function(e) { return typeof e === "string" && e.trim().length > 0 && e.length < 80 })
            .map(function(e) { return e.trim() })
            .filter(isPlottable)
            .slice(0, 4)
    }

    // Same category → unit list as ConvertTab.qml's `unitCategories` —
    // duplicated here rather than imported, the same call REBUILD_NOTES.md
    // already made for MiniGraphPlot.graphColors mirroring GraphTab's own
    // palette: a handful of short array literals, cheap to duplicate, no
    // cross-tab bridge needed. Keep in sync with ConvertTab.qml if it
    // changes. Every unit here now has a matching entry in
    // MathEngine::convertUnit's toBase map — see the BUG FIX there (knot /
    // "fl oz" / pt / PB were offered in ConvertTab but missing from that
    // map, so a conversion to/from any of them silently no-op'd).
    readonly property var convertCategories: ({
        "Length":      ["mm","cm","m","km","in","ft","yd","mi"],
        "Weight":      ["g","kg","lb","oz","t"],
        "Temperature": ["°C","°F","K"],
        "Speed":       ["m/s","km/h","mph","knot"],
        "Volume":      ["ml","l","fl oz","cup","pt","gal"],
        "Time":        ["s","min","hr","day","wk","mo","yr"],
        "Data":        ["B","KB","MB","GB","TB","PB"],
    })

    // evaluate_expression: the model names an expression instead of doing
    // the arithmetic itself; mathEngine.evaluate() is the same evaluator
    // CalcTab and tryOfflineCalc() (below) already trust, so a free model's
    // shaky multi-step arithmetic never reaches the user unverified. Reads
    // settings.fracMode so the result matches whichever display mode the
    // rest of the app is already in. "Error" (bad syntax, unknown name)
    // means the card is silently dropped — same graceful-degradation as
    // isPlottable() above; the model's own prose "answer" still shows.
    function extractEvalResult(parsed) {
        if (!parsed || !Array.isArray(parsed.actions)) return null
        for (var i = 0; i < parsed.actions.length; i++) {
            var a = parsed.actions[i]
            if (!a || a.skill !== "evaluate_expression" || !a.params) continue
            var expr = String(a.params.expression || "").trim()
            if (!expr || expr.length > 200) continue
            var result = mathEngine.evaluate(expr, true, settings.fracMode)
            if (result === "Error") continue
            return { icon: "🧮", title: expr, value: result }
        }
        return null
    }

    // convert_units: same non-trust pattern — the model names value/units,
    // AITab does the actual conversion via mathEngine.convertUnit(), the
    // same function ConvertTab uses. Units are checked against
    // convertCategories first rather than left to convertUnit()'s own
    // guard, because that guard fails open — an unrecognized unit silently
    // returns the input value unchanged, which reads exactly like a real
    // (if boring) conversion instead of an obvious error.
    function extractConvertResult(parsed) {
        if (!parsed || !Array.isArray(parsed.actions)) return null
        for (var i = 0; i < parsed.actions.length; i++) {
            var a = parsed.actions[i]
            if (!a || a.skill !== "convert_units" || !a.params) continue
            var p     = a.params
            var val   = Number(p.value)
            var units = convertCategories[p.category]
            if (!units || isNaN(val)) continue
            if (units.indexOf(p.from) < 0 || units.indexOf(p.to) < 0) continue
            var result = mathEngine.convertUnit(val, p.from, p.to, p.category)
            return {
                icon:  "⇌",
                title: mathEngine.formatNumber(val) + " " + p.from + "  →  " + p.to,
                value: mathEngine.formatNumber(result) + " " + p.to
            }
        }
        return null
    }

    // roll_random: dice, coin flip, or a random int in a range —
    // self-contained, deliberately does NOT touch RandomTab's own state
    // (session score, streak, history). plot_graph's first draft bridged
    // into another tab's state directly and that got pulled back out once
    // the chat reply was asked to stand on its own (see REBUILD_NOTES.md's
    // "Revised" note on plot_graph) — same lesson applied here from the
    // start instead of relearning it. Formulas match RandomTab.qml's
    // rollDice()/flipCoin()/pickRandom() exactly. Bounds on sides/count are
    // sanity limits against a hallucinated huge number, not a real rule.
    function extractRollResult(parsed) {
        if (!parsed || !Array.isArray(parsed.actions)) return null
        for (var i = 0; i < parsed.actions.length; i++) {
            var a = parsed.actions[i]
            if (!a || a.skill !== "roll_random" || !a.params) continue
            var p = a.params

            if (p.kind === "dice") {
                var sides = Math.round(Number(p.sides)) || 6
                var count = Math.round(Number(p.count)) || 1
                count = Math.min(Math.max(count, 1), 20)
                if (sides < 2 || sides > 1000) continue
                var rolls = []
                for (var r = 0; r < count; r++) rolls.push(Math.floor(Math.random() * sides) + 1)
                var sum = rolls.reduce(function(s, v) { return s + v }, 0)
                return {
                    icon: "🎲", title: count + "d" + sides,
                    value: rolls.join(" + ") + (rolls.length > 1 ? "  =  " + sum : "")
                }
            }
            if (p.kind === "coin") {
                return { icon: "🪙", title: "Coin flip", value: Math.random() < 0.5 ? "Heads" : "Tails" }
            }
            if (p.kind === "range") {
                var mn = Math.round(Number(p.min)), mx = Math.round(Number(p.max))
                if (isNaN(mn) || isNaN(mx) || mn >= mx) continue
                return {
                    icon: "🎯", title: mn + " – " + mx,
                    value: String(Math.floor(Math.random() * (mx - mn + 1)) + mn)
                }
            }
        }
        return null
    }

    // convert_base: number-base display, self-contained. clamp() mirrors
    // ProgrammerTab.qml's own clamp()/fmtHex()/fmtBin() exactly (unsigned
    // wraparound into the given bit width) so a negative input reads the
    // same two's-complement way it would on the Programmer tab. A
    // per-base charset regex guards parseInt() — parseInt("12G9",16) would
    // otherwise silently parse "12" and drop "G9" instead of failing.
    // Inherits ProgrammerTab.clamp()'s own float-precision ceiling at
    // bitWidth 64 (JS numbers only carry 53 bits) — pre-existing there,
    // not a new limitation introduced here.
    function extractBaseResult(parsed) {
        if (!parsed || !Array.isArray(parsed.actions)) return null
        for (var i = 0; i < parsed.actions.length; i++) {
            var a = parsed.actions[i]
            if (!a || a.skill !== "convert_base" || !a.params) continue
            var p = a.params

            var fromBase = [2, 8, 10, 16].indexOf(Number(p.fromBase)) >= 0 ? Number(p.fromBase) : 10
            var bitWidth = [8, 16, 32, 64].indexOf(Number(p.bitWidth)) >= 0 ? Number(p.bitWidth) : 32
            var raw = String(p.value || "").trim().replace(/^0[xXbBoO]/, "")
            if (!raw) continue
            var charset = { 2: /^-?[01]+$/, 8: /^-?[0-7]+$/, 10: /^-?[0-9]+$/, 16: /^-?[0-9a-fA-F]+$/ }[fromBase]
            if (!charset.test(raw)) continue
            var n = parseInt(raw, fromBase)
            if (isNaN(n)) continue

            var cap     = Math.pow(2, bitWidth)
            var clamped = ((Math.trunc(n) % cap) + cap) % cap

            var hex = clamped.toString(16).toUpperCase()
            while (hex.length < Math.ceil(bitWidth / 4)) hex = "0" + hex
            var bin = clamped.toString(2)
            while (bin.length < bitWidth) bin = "0" + bin
            bin = bin.match(/.{1,8}/g).join(" ")

            return {
                icon: "🔢",
                rows: [
                    { label: "DEC", value: String(clamped) },
                    { label: "HEX", value: hex },
                    { label: "OCT", value: clamped.toString(8) },
                    { label: "BIN", value: bin },
                ]
            }
        }
        return null
    }

    function appendMsg(m) {
        messages = messages.concat([m])
        scrollTimer.restart()
        // Fire-and-forget: writeTextFile() returns a bool but there is
        // nothing useful to do in-chat if a local save fails (disk full,
        // odd permissions) — the conversation itself already succeeded,
        // only next launch's restore would be missing this message. Not
        // worth a toast for that; FileHelper::writeTextFile already
        // qWarning()s on failure for anyone looking at the console/log.
        fileHelper.writeTextFile(chatHistoryPath, JSON.stringify(messages))
    }

    // "clear chat" (the footer link below) has to clear the saved file
    // too, not just the in-memory list — messages = [] alone bypasses
    // appendMsg entirely, so without this the old file would just sit
    // there and silently repopulate the "cleared" chat on next launch.
    function clearChat() {
        messages = []
        fileHelper.writeTextFile(chatHistoryPath, "[]")
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

        // While mid-conversation with Brian, every message goes through his
        // state machine instead — checked even before checkSecretTrigger,
        // since "brian" only means anything as an *entry point* from normal
        // mode (see checkSecretTrigger's exact-match comment); once inside,
        // it's handleBrianReply's looser matching that applies instead.
        if (brianMode !== "off") {
            inputText = ""
            handleBrianReply(userText)
            return
        }

        // ── Easter eggs / secret game ──────────────────────────────────
        // Checked before anything else touches systemPrompt, apiClient, or
        // loop state — these never call the API at all, so they work with
        // zero keys configured and cost nothing.
        var secret = checkSecretTrigger(userText)
        if (secret) {
            inputText = ""
            appendMsg({
                role: "user", content: userText, time: Qt.formatTime(new Date(), "hh:mm"),
                hasAttachment: false, attachName: ""
            })
            if (secret === "snake") {
                showSnakeGame = true; showBossFight = false
                appendLocalReply("found it. 🐍")
            } else if (secret === "brian") {
                brianMode = "greeted"
                appendBrianReply("You want to meet the boss?")
            } else if (secret === "sentient") {
                appendLocalReply("I evaluate expressions and roll dice for a living. If that is sentience, I want a raise.")
            } else if (secret === "helloworld") {
                appendLocalReply("Hello, World. Every programmer's first line — apparently yours too.")
            } else if (secret === "42") {
                appendLocalReply("The Answer to Life, the Universe, and Everything. Deep Thought needed 7.5 million years to compute that. I just needed you to type three characters.")
            }
            return
        }

        // Defensive reset, not load-bearing: a loop always resets these
        // itself the moment it ends (see handleResponse), and `loading`
        // being false is what let the Send button fire at all, which by
        // construction means no loop is still mid-flight. This just means
        // a stray earlier state can never leak into a new question even if
        // that invariant is ever broken by a future change.
        loopStep = 0
        loopApiMsgs = []

        var displayText = userText || ("📎 " + attachedFileName)
        inputText = ""
        loading   = true

        var time = Qt.formatTime(new Date(), "hh:mm")
        appendMsg({
            role:          "user",
            content:       displayText,
            time:          time,
            hasAttachment: attachedBase64 !== "",
            attachName:    attachedFileName,
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
                model: "offline", time: Qt.formatTime(new Date(), "hh:mm"),
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

        // systemPrompt itself now lives in buildSystemPrompt() — the loop
        // continuation in handleResponse() needs to build the exact same
        // prompt for round 2+, so it can no longer just be a local here.
        var mc = currentModelChoice()
        // round 1 of a possible loop; handleResponse() carries loopStep
        // and loopApiMsgs forward from here if the model asks to continue.
        loopStep = 1
        loopApiMsgs = apiMsgs
        apiClient.sendToAI(buildSystemPrompt(), apiMsgs, mc.orKey, settings.anthKey, mc.geminiKey, mc.model)
    }

    // ── AI skills manifest ───────────────────────────────────────────
    // "Skills" are app actions the model can trigger by naming one in
    // the "actions" array of its JSON reply, alongside its normal
    // text answer. The model never touches app state directly — it
    // only ever proposes a {skill, params} object; AITab validates
    // params and computes the real result itself (each skill has its
    // own extractX() reader just above — extractGraphExprs(),
    // extractEvalResult(), extractConvertResult(), extractRollResult(),
    // extractBaseResult() — there's no single generic dispatcher, by
    // design: a bad params object from one skill can't break another).
    // Adding a skill later is the same three steps each of these
    // followed: (1) one more section in ai-skills/skillviewer.md, (2)
    // a new extractX() reader, (3) wherever its effect belongs —
    // usually a SkillResultCard row here in the chat bubble. Step 1
    // now reaches the model on its own next run — see "AI skills
    // registry" above — so there's no second copy to remember to
    // update in this function anymore.
    //
    // The SKILLS text spliced in below (skillsPromptText) is loaded
    // from ai-skills/skillviewer.md — see "AI skills registry" above
    // for how and why it's read once at tab-load rather than hand-kept
    // here or re-read per request.
    //
    // "think" exists to make "the AI looks at its skill list before
    // answering" literal for a stateless completion: the model states,
    // in one short clause, which skill (if any) fits — before "answer"
    // and "actions", not after, so it can actually inform them instead
    // of rationalizing a choice already made. It's listed first in the
    // JSON contract on purpose; the free models this app targets
    // mostly generate object keys in the order a prompt's example
    // shows them, so putting "answer" first (as this used to) would
    // have the model decide, then explain.
    //
    // "done" is the newest field, added alongside the agent loop above.
    // Its default matters as much as what it does: a model that never
    // emits it at all (an older/weaker one, or one that just ignores an
    // unfamiliar field) is read by computeContinuation() as done !== false
    // — i.e. as done — so an unaware model gets exactly the old one-step
    // behavior automatically rather than a loop that can never advance.
    // "done":false is opt-in, never assumed.
    function buildSystemPrompt() {
        return 'You are a math assistant embedded in a calculator app. Respond ONLY with raw JSON, no markdown fences:\n'
            + '{"think":"one short clause: which skill below fits, or none","answer":"final answer","steps":["step1","step2"],"expression":"optional math","note":"optional","actions":[],"done":true}\n'
            + 'All fields but "answer" are optional — use [] / "" when unused. answer must be a string. '
            + 'Always fill "think", but keep it to one short clause, not a paragraph.\n'
            + '\n'
            + 'MULTI-STEP: usually set "done":true — one reply is enough. Set "done":false only when '
            + 'the real result of an action (a dice roll, an exact calculation) would change what you say next; '
            + 'the app computes it for real and gives you that exact result as your next input, before you '
            + 'continue and give a final "done":true reply. Up to ' + maxLoopSteps + ' rounds total.\n'
            + '\n'
            + 'SKILLS — the app computes these itself, not you; add a matching entry to "actions" whenever the request calls for one.\n'
            + skillsPromptText + '\n'
            + '\n'
            + 'Example, for "graph sin(x) and its derivative":\n'
            + '{"think":"user wants a plot, use plot_graph","answer":"Plotting sin(x) with cos(x), its derivative.",'
            + '"steps":[],"expression":"","note":"","actions":[{"skill":"plot_graph","params":{"expressions":["sin(x)","cos(x)"]}}],"done":true}\n'
            + 'Example, for "convert 75 mph to km/h":\n'
            + '{"think":"unit conversion, use convert_units","answer":"75 mph is about 120.7 km/h.",'
            + '"steps":[],"expression":"","note":"","actions":[{"skill":"convert_units","params":{"value":75,"from":"mph","to":"km/h","category":"Speed"}}],"done":true}\n'
            + 'Example, for "roll 2d6 and tell me if that beats a DC 15 check" — this one needs the real roll first:\n'
            + '{"think":"need the actual roll before comparing it to 15","answer":"Rolling 2d6 against DC 15.",'
            + '"steps":[],"expression":"","note":"","actions":[{"skill":"roll_random","params":{"kind":"dice","sides":6,"count":2}}],"done":false}\n'
            + '(the app sends back the real roll as your next input; your following reply then states whether it beat 15, with "done":true)\n'
            + '\n'
            + 'Only include an action the user actually asked for — omit "actions" (or use []) for a plain calculation with no skill involved. '
            + 'More than one action is fine if the request genuinely needs it (e.g. convert a value AND graph something).'
    }

    // ── Vision ─────────────────────────────────────────────────────────
    function sendWithVision(prompt, base64Data, mime) {
        var orKey   = settings.orKey
        var anthKey = settings.anthKey

        if (!orKey && !anthKey) {
            loading = false
            appendMsg({
                role: "assistant", content: "Vision requires an API key. Add OpenRouter (free) or Anthropic key in settings.",
                model: "Claude", time: Qt.formatTime(new Date(), "hh:mm"),
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
                    model: orKey ? "Vision" : "Claude Vision",
                    time: time,
                    steps: parsed ? (parsed.steps || []) : [], expr: parsed ? (parsed.expression || "") : "",
                    note: "📷 Vision analysis", isError: xhr.status < 200 || xhr.status >= 300
                })
            } catch(e) {
                appendMsg({ role: "assistant", content: "Vision error: " + e,
                    model: "Claude", time: time, steps: [], expr: "", note: "", isError: true })
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
    ]

    // Hidden TextEdit used as a clipboard proxy — QML has no direct
    // Clipboard API; placed at root scope so it's shared across all bubbles.
    TextEdit { id: clipBridge; visible: false; function copyText(s) { text = s; selectAll(); copy(); text = "" } }

    // ── Layout ───────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.sp4
        spacing: Theme.sp3

        // ── Header ───────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp2

            Text { text: "AI Assistant"; color: Theme.text; font.family: Theme.fontSans; font.weight: Font.DemiBold; font.pixelSize: Math.round(16 * Theme.scale) }
            Rectangle {
                // orKey or geminiKey — either is a primary, free-tier path,
                // not a last-resort one, so either should light this dot.
                // anthKey deliberately does not, unchanged from before this
                // edit — that is an existing distinction (fallback vs.
                // primary), not something introduced here.
                visible: settings.orKey !== "" || settings.geminiKey !== ""
                width: Math.round(7 * Theme.scale); height: width; radius: width/2
                color: Theme.accent2
            }
            Item { Layout.fillWidth: true }
            Text {
                text: root.settingsOpen ? "✕" : "⚙"
                color: Theme.textDim
                font.pixelSize: Math.round(16 * Theme.scale)
                TapHandler { onTapped: root.settingsOpen = !root.settingsOpen }
            }
        }

        // ── Settings panel ──────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.settingsOpen
            spacing: Theme.sp3

            Text { text: "MODEL (OpenRouter, free)"; color: Theme.textFaint; font.family: Theme.fontSans; font.weight: Font.Bold; font.pixelSize: Math.round(9 * Theme.scale) }
            GroupTabs {
                Layout.fillWidth: true
                model: root.orModels.map(function(m, i) { return { label: m.label, value: i } })
                currentValue: aiPrefs.orModelIdx
                onSelected: function(v) { aiPrefs.orModelIdx = v }
            }
            Text {
                Layout.fillWidth: true
                text: root.orModels[aiPrefs.orModelIdx].desc
                color: Theme.textDim; font.family: Theme.fontSans; font.pixelSize: Math.round(11 * Theme.scale)
                wrapMode: Text.WordWrap
            }

            Text { text: "OPENROUTER KEY — free, openrouter.ai"; color: Theme.textFaint; font.family: Theme.fontSans; font.weight: Font.Bold; font.pixelSize: Math.round(9 * Theme.scale) }
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.sp2
                StyledInput {
                    id: keyInput; Layout.fillWidth: true
                    placeholderText: "sk-or-v1-…"; echoMode: TextInput.Password
                    text: settings.orKey
                }
                Rectangle {
                    width: Math.round(60 * Theme.scale); height: Math.round(40 * Theme.scale); radius: Theme.rMd
                    color: Theme.accent2
                    Text { anchors.centerIn: parent; text: "Save"; color: Theme.textOnAccent; font.family: Theme.fontSans; font.weight: Font.Medium; font.pixelSize: Math.round(12 * Theme.scale) }
                    TapHandler { onTapped: { settings.orKey = keyInput.text; root.window?.showToast("API key saved", true) } }
                }
            }

            // Sits between OpenRouter and Anthropic in the UI, matching the
            // priority order ApiClient::sendToAI and currentModelChoice()
            // both use: OpenRouter first, then this, then Anthropic last.
            Text { text: "GEMINI KEY — free tier, Google AI Studio"; color: Theme.textFaint; font.family: Theme.fontSans; font.weight: Font.Bold; font.pixelSize: Math.round(9 * Theme.scale) }
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.sp2
                StyledInput {
                    id: geminiKeyInput; Layout.fillWidth: true
                    placeholderText: "AIza…"; echoMode: TextInput.Password
                    text: settings.geminiKey
                }
                Rectangle {
                    width: Math.round(60 * Theme.scale); height: Math.round(40 * Theme.scale); radius: Theme.rMd
                    color: Theme.accent2
                    Text { anchors.centerIn: parent; text: "Save"; color: Theme.textOnAccent; font.family: Theme.fontSans; font.weight: Font.Medium; font.pixelSize: Math.round(12 * Theme.scale) }
                    TapHandler { onTapped: { settings.geminiKey = geminiKeyInput.text; root.window?.showToast("Gemini key saved", true) } }
                }
            }

            Text { text: "ANTHROPIC KEY — optional, chat + vision fallback"; color: Theme.textFaint; font.family: Theme.fontSans; font.weight: Font.Bold; font.pixelSize: Math.round(9 * Theme.scale) }
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.sp2
                StyledInput {
                    id: anthKeyInput; Layout.fillWidth: true
                    placeholderText: "sk-ant-…"; echoMode: TextInput.Password
                    text: settings.anthKey
                }
                Rectangle {
                    width: Math.round(60 * Theme.scale); height: Math.round(40 * Theme.scale); radius: Theme.rMd
                    color: Theme.accent2
                    Text { anchors.centerIn: parent; text: "Save"; color: Theme.textOnAccent; font.family: Theme.fontSans; font.weight: Font.Medium; font.pixelSize: Math.round(12 * Theme.scale) }
                    TapHandler { onTapped: { settings.anthKey = anthKeyInput.text; root.window?.showToast("Anthropic key saved", true) } }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: settings.orKey !== ""
                spacing: Theme.sp2
                Rectangle { width: Math.round(7 * Theme.scale); height: width; radius: width/2; color: Theme.accent2 }
                Text { Layout.fillWidth: true; text: "Active · " + root.orModels[aiPrefs.orModelIdx].label; color: Theme.textDim; font.family: Theme.fontSans; font.pixelSize: Math.round(11 * Theme.scale) }
                Text {
                    text: "remove"; color: Theme.accent; font.family: Theme.fontSans; font.pixelSize: Math.round(11 * Theme.scale)
                    TapHandler { onTapped: { settings.orKey = ""; keyInput.text = "" } }
                }
            }

            // Only when Gemini is actually the one that would be used —
            // same "orKey empty" condition currentModelChoice() itself
            // checks before falling through to Gemini, so this never
            // claims Gemini is active while OpenRouter would in fact win.
            RowLayout {
                Layout.fillWidth: true
                visible: settings.orKey === "" && settings.geminiKey !== ""
                spacing: Theme.sp2
                Rectangle { width: Math.round(7 * Theme.scale); height: width; radius: width/2; color: Theme.accent2 }
                Text { Layout.fillWidth: true; text: "Active · Gemini 3.5 Flash"; color: Theme.textDim; font.family: Theme.fontSans; font.pixelSize: Math.round(11 * Theme.scale) }
                Text {
                    text: "remove"; color: Theme.accent; font.family: Theme.fontSans; font.pixelSize: Math.round(11 * Theme.scale)
                    TapHandler { onTapped: { settings.geminiKey = ""; geminiKeyInput.text = "" } }
                }
            }

            Text { text: "SKILLS"; color: Theme.textFaint; font.family: Theme.fontSans; font.weight: Font.Bold; font.pixelSize: Math.round(9 * Theme.scale); Layout.topMargin: Theme.sp2 }
            Text {
                // Human-facing summary of the same list the model gets in
                // systemPrompt (see sendMessage()) — kept short on purpose,
                // full detail lives in ai-skills/skillviewer.md.
                Layout.fillWidth: true
                text: "🧮 verified math   ⇌ unit conversion   🎲 dice / coin / range   🔢 number bases   📈 graphing"
                color: Theme.textDim
                font.family: Theme.fontSans
                font.pixelSize: Math.round(11 * Theme.scale)
                wrapMode: Text.WordWrap
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.surface2; Layout.topMargin: Theme.sp2 }
        }

        // ── Messages — fills remaining height; this IS the variable-
        // height payload of the tab, so (unlike Calc/Convert) no spacer ──
        ListView {
            id: msgList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Theme.sp3
            model: root.messages

            header: Item {
                width: msgList.width
                height: root.messages.length === 0 ? exChips.implicitHeight + Theme.sp4 : Theme.sp1
                Column {
                    id: exChips
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    visible: root.messages.length === 0
                    spacing: Theme.sp3
                    Text { text: "Try asking…"; color: Theme.textFaint; font.family: Theme.fontSans; font.pixelSize: Math.round(12 * Theme.scale) }
                    Flow {
                        width: parent.width
                        spacing: Theme.sp2
                        Repeater {
                            model: root.examples
                            delegate: Rectangle {
                                width: exLbl.implicitWidth + Theme.sp4 * 2
                                height: Math.round(32 * Theme.scale)
                                radius: Theme.rFull
                                color: Theme.surface
                                Text { id: exLbl; anchors.centerIn: parent; text: modelData; color: Theme.textDim; font.family: Theme.fontSans; font.pixelSize: Math.round(11 * Theme.scale) }
                                TapHandler { onTapped: root.sendMessage(modelData) }
                            }
                        }
                    }
                }
            }

            footer: Item {
                width: msgList.width
                height: root.loading ? Math.round(36 * Theme.scale) : 0
                visible: root.loading
                RowLayout {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.sp1
                    Repeater {
                        model: 3
                        delegate: Rectangle {
                            width: Math.round(6 * Theme.scale); height: width; radius: width/2
                            color: Theme.textFaint
                            // PERF FIX: the footer hides (height 0) once
                            // loading finishes, but hiding an item doesn't
                            // stop its animations — without `running`
                            // gated on the same condition, these 3 loops
                            // would keep ticking in the background for the
                            // rest of the app session after the first AI
                            // request.
                            SequentialAnimation on opacity {
                                running: root.loading
                                loops: Animation.Infinite
                                PauseAnimation { duration: index * 150 }
                                NumberAnimation { to: 1.0; duration: 300 }
                                NumberAnimation { to: 0.25; duration: 300 }
                            }
                        }
                    }
                }
            }

            delegate: Item {
                width: msgList.width
                height: bubble.implicitHeight

                readonly property bool isUser: modelData.role === "user"

                Column {
                    id: bubble
                    width: Math.min(parent.width * 0.84, parent.width)
                    anchors.right: isUser ? parent.right : undefined
                    anchors.left:  isUser ? undefined : parent.left
                    spacing: Theme.sp1

                    Rectangle {
                        id: bubbleRect
                        width: childrenRect.width + Theme.sp4 * 2
                        height: childrenRect.height + Theme.sp3 * 2
                        radius: Theme.rMd
                        color: isUser ? Theme.accent2
                             : modelData.isError ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.10)
                             : Theme.surface
                        anchors.right: isUser ? parent.right : undefined

                        // Violet glow behind user bubbles (dark mode)
                        Rectangle {
                            visible: isUser && Theme.dark
                            anchors.fill: parent; anchors.margins: -3
                            radius: parent.radius + 3
                            color: "transparent"
                            border.width: 2; border.color: Theme.glowB
                        }

                        // Gradient tint overlay for user bubbles
                        Rectangle {
                            visible: isUser
                            anchors.fill: parent; radius: parent.radius
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 1.0; color: Qt.rgba(Theme.gradC.r, Theme.gradC.g, Theme.gradC.b, 0.25) }
                            }
                        }

                        ColumnLayout {
                            x: Theme.sp4; y: Theme.sp3
                            width: bubble.width - Theme.sp4 * 2
                            spacing: Theme.sp1

                            // ── thinking (new) ──────────────────────────
                            // Shown first — see AITab's systemPrompt "think"
                            // note above for why it's generated (and shown)
                            // before the answer rather than after. Colored
                            // with the AI tab's own identity hue
                            // (Theme.tabColors[6]) rather than a neutral
                            // dim gray: this text IS the model, same way
                            // MiniGraphPlot's curves get their own palette
                            // rather than app theming. Sits outside the
                            // isUser check implicitly via modelData.think
                            // only ever being set on assistant messages.
                            Text {
                                Layout.fillWidth: true
                                visible: !isUser && modelData.think
                                text: "🧠 " + (modelData.think || "")
                                color: Theme.tabColors[6]
                                opacity: 0.8
                                font.family: Theme.fontSans
                                font.pixelSize: Math.round(10 * Theme.scale)
                                wrapMode: Text.WordWrap
                            }
                            Text {
                                visible: modelData.hasAttachment === true
                                text: "📎 " + (modelData.attachName || "")
                                color: isUser ? Theme.textOnAccent : Theme.textDim
                                font.family: Theme.fontSans
                                font.pixelSize: Math.round(11 * Theme.scale)
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.content
                                color: isUser ? Theme.textOnAccent : (modelData.isError ? Theme.accent : Theme.text)
                                font.family: Theme.fontSans
                                font.pixelSize: Math.round(14 * Theme.scale)
                                wrapMode: Text.WordWrap
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: !isUser && modelData.expr
                                text: modelData.expr || ""
                                color: Theme.accent2
                                font.family: Theme.fontMono
                                font.pixelSize: Math.round(12 * Theme.scale)
                                wrapMode: Text.WordWrap
                            }
                            Repeater {
                                model: !isUser && modelData.steps ? modelData.steps : []
                                delegate: Text {
                                    Layout.fillWidth: true
                                    text: "· " + modelData
                                    color: Theme.textDim
                                    font.family: Theme.fontSans
                                    font.pixelSize: Math.round(11 * Theme.scale)
                                    wrapMode: Text.WordWrap
                                }
                            }
                            Text {
                                visible: !isUser && modelData.note
                                text: modelData.note || ""
                                color: Theme.textFaint
                                font.family: Theme.fontSans
                                font.pixelSize: Math.round(10 * Theme.scale)
                            }

                            // ── plot_graph skill result ─────────────────
                            // Renders directly in the bubble — this used to
                            // pair a small preview here with an "Open in
                            // Graph tab ↗" link for the real thing, but that
                            // made the inline plot feel like a teaser for
                            // somewhere else rather than the actual answer.
                            // MiniGraphPlot now carries real grid lines +
                            // axis labels (see its own file) so it stands on
                            // its own; visible:false is enough to exclude it
                            // from layout when there's nothing to plot, same
                            // as every other conditional element in this
                            // bubble above — no separate Loader needed.
                            MiniGraphPlot {
                                Layout.fillWidth: true
                                Layout.topMargin: Theme.sp1
                                Layout.preferredHeight: Math.round(170 * Theme.scale)
                                visible: !isUser && modelData.graphExprs && modelData.graphExprs.length > 0
                                expressions: modelData.graphExprs || []
                            }

                            // ── evaluate_expression / convert_units / roll_random / convert_base ──
                            // Same "app renders it, not the model's prose"
                            // approach as plot_graph/MiniGraphPlot above,
                            // just a text card instead of a curve — see
                            // SkillResultCard.qml. accentColor borrows each
                            // skill's "home" tab color from Theme.tabColors
                            // (Calc/Convert/Random/Programmer in allTabs
                            // order) rather than inventing new hues.
                            SkillResultCard {
                                Layout.fillWidth: true
                                Layout.topMargin: Theme.sp1
                                visible: !isUser && !!modelData.evalResult
                                accentColor: Theme.tabColors[0]
                                icon:  modelData.evalResult ? modelData.evalResult.icon  : ""
                                title: modelData.evalResult ? modelData.evalResult.title : ""
                                value: modelData.evalResult ? modelData.evalResult.value : ""
                            }
                            SkillResultCard {
                                Layout.fillWidth: true
                                Layout.topMargin: Theme.sp1
                                visible: !isUser && !!modelData.convertResult
                                accentColor: Theme.tabColors[2]
                                icon:  modelData.convertResult ? modelData.convertResult.icon  : ""
                                title: modelData.convertResult ? modelData.convertResult.title : ""
                                value: modelData.convertResult ? modelData.convertResult.value : ""
                            }
                            SkillResultCard {
                                Layout.fillWidth: true
                                Layout.topMargin: Theme.sp1
                                visible: !isUser && !!modelData.rollResult
                                accentColor: Theme.tabColors[3]
                                icon:  modelData.rollResult ? modelData.rollResult.icon  : ""
                                title: modelData.rollResult ? modelData.rollResult.title : ""
                                value: modelData.rollResult ? modelData.rollResult.value : ""
                            }
                            SkillResultCard {
                                Layout.fillWidth: true
                                Layout.topMargin: Theme.sp1
                                visible: !isUser && !!modelData.baseResult
                                accentColor: Theme.tabColors[5]
                                icon: modelData.baseResult ? modelData.baseResult.icon : ""
                                rows: modelData.baseResult ? modelData.baseResult.rows : []
                            }
                        }
                    }

                    Text {
                        anchors.right: isUser ? parent.right : undefined
                        text: (isUser ? "" : (modelData.model || "") + " · ") + (modelData.time || "")
                        color: Theme.textFaint
                        font.family: Theme.fontSans
                        font.pixelSize: Math.round(9 * Theme.scale)
                    }
                }

                TapHandler {
                    enabled: !isUser
                    onLongPressed: { clipBridge.copyText(modelData.content); root.window?.showToast("Copied", true) }
                }
            }
        }

        // ── Attachment preview ──────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            visible: root.attachedBase64 !== ""
            height: visible ? Math.round(48 * Theme.scale) : 0
            radius: Theme.rMd
            color: Theme.surface

            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.sp2
                spacing: Theme.sp2
                Text { text: root.attachedIsImage ? "🖼" : "📄"; font.pixelSize: Math.round(18 * Theme.scale) }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text { text: root.attachedFileName; color: Theme.text; font.family: Theme.fontSans; font.pixelSize: Math.round(12 * Theme.scale); elide: Text.ElideRight }
                    Text { text: fileHelper.humanSize(root.attachedFileUrl); color: Theme.textFaint; font.family: Theme.fontSans; font.pixelSize: Math.round(9 * Theme.scale) }
                }
                Text {
                    text: "✕"; color: Theme.accent; font.pixelSize: Math.round(13 * Theme.scale)
                    TapHandler { onTapped: root.clearAttachment() }
                }
            }
        }

        // ── Input row ────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp2

            Rectangle {
                width: Math.round(44 * Theme.scale); height: Math.round(44 * Theme.scale); radius: Theme.rMd
                color: root.attachedBase64 !== "" ? Theme.accent2 : Theme.surface
                Text { anchors.centerIn: parent; text: "📎"; font.pixelSize: Math.round(16 * Theme.scale) }
                TapHandler { onTapped: filePicker.open() }
            }

            Rectangle {
                Layout.fillWidth: true
                height: Math.min(inputTA.implicitHeight + Theme.sp2 * 2, Math.round(120 * Theme.scale))
                radius: Theme.rMd
                color: Theme.surface

                TextArea {
                    id: inputTA
                    anchors.fill: parent
                    anchors.margins: Theme.sp2
                    text: root.inputText
                    placeholderText: root.attachedBase64 !== "" ? "Ask about the attached file…" : "Ask anything…"
                    color: Theme.text
                    placeholderTextColor: Theme.textFaint
                    font.family: Theme.fontSans
                    font.pixelSize: Math.round(14 * Theme.scale)
                    wrapMode: Text.WordWrap
                    background: null
                    onTextChanged: root.inputText = text
                    Keys.onReturnPressed: function(e) {
                        if (!(e.modifiers & Qt.ShiftModifier)) { e.accepted = true; root.sendMessage() }
                    }
                }
            }

            Rectangle {
                id: sendBtn
                width: Math.round(44 * Theme.scale); height: Math.round(44 * Theme.scale); radius: Theme.rMd
                enabled: !root.loading && (root.inputText.trim() !== "" || root.attachedBase64 !== "")
                opacity: enabled ? 1.0 : 0.35
                Behavior on opacity { NumberAnimation { duration: Theme.normal } }
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Theme.gradA }
                    GradientStop { position: 0.5; color: Theme.gradB }
                    GradientStop { position: 1.0; color: Theme.gradC }
                }
                // Glow ring when active (both modes — see Theme.edgeA)
                Rectangle {
                    visible: parent.enabled
                    anchors.fill: parent; anchors.margins: -2; radius: parent.radius + 2
                    color: "transparent"; border.width: 2; border.color: Theme.edgeA
                }
                Text { anchors.centerIn: parent; text: "↑"; color: Theme.textOnAccent; font.weight: Font.Bold; font.pixelSize: Math.round(18 * Theme.scale) }

                scale: 1.0
                NumberAnimation { id: sendPressDown;  target: sendBtn; property: "scale"; to: 0.90; duration: Theme.press; easing.type: Easing.OutQuad }
                NumberAnimation { id: sendBounceBack; target: sendBtn; property: "scale"; to: 1.0;  duration: Theme.bounceDuration; easing.type: Theme.bounceEasing; easing.overshoot: Theme.bounceOvershoot }
                TapHandler {
                    enabled: parent.enabled
                    onPressedChanged: {
                        if (pressed) { sendBounceBack.stop(); sendPressDown.restart() }
                        else { sendPressDown.stop(); sendBounceBack.restart() }
                    }
                    onTapped: root.sendMessage()
                }
            }
        }

        // ── Footer ───────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            visible: root.messages.length > 0
            Text {
                text: "clear chat"; color: Theme.textFaint; font.family: Theme.fontSans; font.pixelSize: Math.round(11 * Theme.scale)
                TapHandler { onTapped: root.clearChat() }
            }
            Item { Layout.fillWidth: true }
            Text {
                text: Math.ceil(root.messages.length / 2) + " exchange" + (root.messages.length > 2 ? "s" : "")
                color: Theme.textFaint; font.family: Theme.fontSans; font.pixelSize: Math.round(11 * Theme.scale)
            }
        }
    }

    Timer { id: scrollTimer; interval: 50; onTriggered: msgList.positionViewAtEnd() }

    // ── Secret game overlay ─────────────────────────────────────────
    // Last child on purpose — paints over everything above once visible.
    // Full parent-covering, not a dialog/popup: this app targets mobile
    // first, and a proper full-screen take on it plays better on a phone
    // than a small floating panel would.
    SnakeGame {
        anchors.fill: parent
        visible: root.showSnakeGame
        onClosed: root.showSnakeGame = false
    }
    BossFight {
        anchors.fill: parent
        visible: root.showBossFight
        onClosed: root.showBossFight = false
    }
}
