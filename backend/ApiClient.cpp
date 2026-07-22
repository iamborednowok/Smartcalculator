#include "ApiClient.h"
#include <QNetworkRequest>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QUrl>

// QOL FIX: was 15000. Free OpenRouter models run on shared, sometimes
// oversubscribed capacity — 15 s was clipping legitimate-but-slow
// responses (especially from bigger models like Nemotron 3 Super/Ultra)
// as timeouts. 25 s gives real slow-but-working requests room without
// leaving the user staring at a spinner indefinitely on a truly dead one.
static constexpr int REQUEST_TIMEOUT_MS = 25000;  // 25 s
// QOL FIX: was 1000, inline in both branches below. The response is a
// JSON object with a "steps" array (see AITab.qml's systemPrompt) — a
// multi-step word-problem walkthrough plus JSON structural overhead
// (quotes, brackets, commas) could genuinely run past 1000 tokens and get
// cut off mid-answer. 1500 gives a full multi-step answer real room
// without being wasteful on short ones (max_tokens is a ceiling, not a
// target — models still stop early on a short answer).
// QOL FIX: 1500 → 1700. The JSON contract now also asks for a "think"
// clause ahead of "answer" (see AITab.qml's systemPrompt + skillviewer.md)
// on every reply, not just word problems — a small fixed per-request cost
// that a 1500 ceiling didn't leave room for on top of an already-long
// multi-step answer.
static constexpr int MAX_TOKENS = 1700;

ApiClient::ApiClient(QObject *parent) : QObject(parent)
{
    m_timeout.setSingleShot(true);
    connect(&m_timeout, &QTimer::timeout, this, [this]() {
        if (m_reply) {
            m_reply->abort();   // triggers onReplyFinished with an error
        }
    });
}

void ApiClient::setLoading(bool v)
{
    if (m_loading == v) return;
    m_loading = v;
    emit loadingChanged();
}

void ApiClient::sendToAI(const QString &systemPrompt,
                          const QVariantList &messages,
                          const QString &openRouterKey,
                          const QString &anthropicKey,
                          const QString &geminiKey,
                          const QString &model)
{
    if (m_loading) return;

    // BUG FIX: this used to branch into an Anthropic request whenever
    // openRouterKey was empty, but built it with a hardcoded empty
    // x-api-key header — the real Anthropic key was never plumbed through
    // from AppSettings at all, so that branch was guaranteed to 401 on
    // every single call. Fail fast with an actionable message instead of
    // firing a network request that cannot possibly succeed.
    if (openRouterKey.isEmpty() && geminiKey.isEmpty() && anthropicKey.isEmpty()) {
        emit responseReceived(
            "Add a free OpenRouter key, a Gemini key, or an Anthropic key in AI settings (tap ⚙ above) to chat.",
            true);
        return;
    }

    QJsonArray msgArray;
    for (const QVariant &m : messages) {
        QVariantMap map = m.toMap();
        QJsonObject obj;
        obj["role"]    = map["role"].toString();
        obj["content"] = map["content"].toString();
        msgArray.append(obj);
    }

    QNetworkRequest req;
    QJsonObject body;

    // Priority: OpenRouter's free lineup first (the app's long-standing
    // default), then Gemini (also a genuine free tier, via Google AI
    // Studio), then the Anthropic fallback last — matching how its own
    // Q_PROPERTY doc comment in AppSettings.h already describes it.
    // Flipped from this function's original "if openRouterKey.isEmpty()"
    // framing (which put the Anthropic branch first): that polarity made
    // sense for a straight either/or between two keys, but reads backward
    // once there is a real third option to slot in ahead of the fallback.
    if (!openRouterKey.isEmpty()) {
        req.setUrl(QUrl("https://openrouter.ai/api/v1/chat/completions"));
        req.setRawHeader("Authorization", ("Bearer " + openRouterKey).toUtf8());
        req.setRawHeader("HTTP-Referer",  "https://smartcalc.app");
        req.setRawHeader("X-Title",       "SmartCalc");   // matches sendWithVision's headers in AITab.qml; OpenRouter's own convention for identifying the calling app

        QJsonObject sysMsg;
        sysMsg["role"]    = "system";
        sysMsg["content"] = systemPrompt;
        QJsonArray full;
        full.append(sysMsg);
        for (const QJsonValue &v : msgArray) full.append(v);

        body["model"]      = model;
        body["max_tokens"] = MAX_TOKENS;
        body["messages"]   = full;
    } else if (!geminiKey.isEmpty()) {
        // Google AI Studio / Gemini Developer API. Structurally the odd
        // one out of the three: "contents" instead of "messages", a
        // "model" role instead of "assistant", the system prompt as its
        // own top-level systemInstruction field rather than a role in the
        // message list or a top-level "system" string, and the key goes
        // in a header Google defines itself rather than a Bearer/x-api-key
        // convention shared with anything else here.
        //
        // model (the parameter, e.g. "gemini-3.5-flash") goes in the URL
        // path for this API, not the body, hence :generateContent below —
        // the one thing this branch does that the other two do not need to.
        req.setUrl(QUrl("https://generativelanguage.googleapis.com/v1beta/models/"
                         + model + ":generateContent"));
        req.setRawHeader("x-goog-api-key", geminiKey.toUtf8());

        QJsonArray contents;
        for (const QJsonValue &v : msgArray) {
            QJsonObject m = v.toObject();
            QJsonObject part;
            part["text"] = m["content"].toString();
            QJsonArray parts;
            parts.append(part);
            QJsonObject turn;
            // Gemini's two roles are "user" and "model" — everywhere else
            // in this app (AITab.qml's messages, both other branches
            // here) calls the second one "assistant"; this is the one
            // place that needs translating, not a shape AITab.qml itself
            // should need to know about.
            turn["role"]  = (m["role"].toString() == "assistant") ? "model" : "user";
            turn["parts"] = parts;
            contents.append(turn);
        }
        body["contents"] = contents;

        QJsonObject sysTextPart;
        sysTextPart["text"] = systemPrompt;
        QJsonArray sysPartsArr;
        sysPartsArr.append(sysTextPart);
        QJsonObject sysInstruction;
        sysInstruction["parts"] = sysPartsArr;
        body["systemInstruction"] = sysInstruction;

        QJsonObject genConfig;
        genConfig["maxOutputTokens"] = MAX_TOKENS;
        // Gemini 3.x models think by default. This app already asks for
        // its own short "think" clause inside the JSON contract itself
        // (see AITab.qml's buildSystemPrompt()) — native extended
        // reasoning on top of that adds latency/cost without changing
        // what JSON actually needs to come out the other end. "low" (not
        // disabling it outright, which not every model/route supports)
        // keeps that native step brief instead.
        QJsonObject thinkingConfig;
        thinkingConfig["thinkingLevel"] = "low";
        genConfig["thinkingConfig"] = thinkingConfig;
        body["generationConfig"] = genConfig;
    } else {
        // Direct Anthropic path — final fallback. Now actually uses the
        // saved key.
        req.setUrl(QUrl("https://api.anthropic.com/v1/messages"));
        req.setRawHeader("x-api-key", anthropicKey.toUtf8());
        req.setRawHeader("anthropic-version", "2023-06-01");
        body["model"]      = model;
        body["max_tokens"] = MAX_TOKENS;

        // Prompt caching: systemPrompt is identical on every single call —
        // every round of an agent-loop exchange (see AITab.qml's
        // buildSystemPrompt()/computeContinuation()) resends the exact
        // same ~1,850-token scaffold, and it does not change between
        // separate questions in the same session either. cache_control on
        // this one block tells Anthropic to cache everything up to and
        // including it (system, in this request — there are no tools
        // here) so a matching later request reads it back at roughly a
        // tenth of the input-token cost instead of fully reprocessing it.
        // No beta header needed — this graduated out of the old
        // "anthropic-beta: prompt-caching-*" opt-in a while back.
        //
        // Caveats worth knowing, not worked around here:
        // - 5-minute TTL (extendable to 1 h via a "ttl" key in
        //   cache_control, at extra cost) — comfortably covers a full
        //   agent-loop exchange, less reliably covers two separate
        //   questions asked minutes apart.
        // - Cache WRITES cost 25% more than a normal call; only reads
        //   (a repeat within the TTL) are discounted. A true one-shot
        //   question that never gets a follow-up costs marginally more,
        //   not less — the saving shows up across a loop's rounds or a
        //   multi-turn conversation, not on an isolated first message.
        // - This only caches systemPrompt, not the growing message
        //   history (msgArray below) — the bigger, safer win to take
        //   first. A second breakpoint on the second-to-last message
        //   would extend caching to long conversation history too, at
        //   the cost of touching the per-message JSON shape as well;
        //   left for a later pass rather than widening this change.
        // - OpenRouter's free-model lineup and Gemini (both above) are
        //   deliberately NOT touched here: cache_control is an
        //   Anthropic-specific field, and whether OpenRouter's rotating
        //   free providers or Gemini tolerate an unrecognized field
        //   gracefully isn't something this environment can verify
        //   against the live API. Silently breaking either path to speed
        //   up the fallback one would be a bad trade.
        QJsonObject sysBlock;
        sysBlock["type"] = "text";
        sysBlock["text"] = systemPrompt;
        QJsonObject cacheControl;
        cacheControl["type"] = "ephemeral";
        sysBlock["cache_control"] = cacheControl;
        QJsonArray sysArr;
        sysArr.append(sysBlock);
        body["system"]   = sysArr;
        body["messages"] = msgArray;
    }

    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

    setLoading(true);
    m_reply = m_nam.post(req, QJsonDocument(body).toJson());
    connect(m_reply, &QNetworkReply::finished, this, &ApiClient::onReplyFinished);

    // FIX: start timeout watchdog — abort if server doesn't respond in 25 s
    m_timeout.start(REQUEST_TIMEOUT_MS);
}

void ApiClient::cancel()
{
    m_timeout.stop();
    if (m_reply) m_reply->abort();
}

void ApiClient::onReplyFinished()
{
    m_timeout.stop();
    setLoading(false);

    if (!m_reply) return;
    m_reply->deleteLater();

    // Capture everything reply-dependent into locals *before* clearing
    // m_reply — every branch below reads only these, never m_reply itself,
    // so there's no risk of a stale/null dereference regardless of which
    // branch runs.
    const int httpStatus = m_reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QNetworkReply::NetworkError netErr = m_reply->error();
    const QString qtErrorString = m_reply->errorString();
    const QByteArray data = m_reply->readAll();
    m_reply = nullptr;

    if (netErr != QNetworkReply::NoError) {
        if (netErr == QNetworkReply::OperationCanceledError) {
            emit responseReceived("Request timed out (25 s)", true);
            return;
        }
        // QOL FIX: this used to show only Qt's generic errorString() (e.g.
        // just "server replied: Too Many Requests") and discard the
        // response body entirely on any non-2xx. Providers put the
        // actually useful detail — which limit, which key, how long to
        // wait — in a JSON error body, not the HTTP reason phrase. Try
        // that first now; fall back to a plain-language note for the two
        // most common free-tier failure modes if the body doesn't have
        // one; fall back to Qt's generic string only if neither applies
        // (e.g. no server was even reached — no body to read at all).
        QString providerMsg = QJsonDocument::fromJson(data).object()["error"].toObject()["message"].toString();
        if (providerMsg.isEmpty() && httpStatus == 401)
            providerMsg = "That API key was rejected — double-check it in AI settings (⚙).";
        else if (providerMsg.isEmpty() && httpStatus == 429)
            providerMsg = "Rate limited — free models allow a handful of requests per minute. Try again shortly.";
        emit responseReceived(providerMsg.isEmpty() ? qtErrorString : providerMsg, true);
        return;
    }

    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (doc.isNull()) {
        emit responseReceived("Invalid JSON response", true);
        return;
    }

    QJsonObject obj = doc.object();
    QString content;

    // Anthropic format: obj["content"][0]["text"]
    if (obj.contains("content") && obj["content"].isArray()) {
        QJsonArray arr = obj["content"].toArray();
        for (const QJsonValue &v : arr) {
            if (v.toObject()["type"].toString() == "text")
                content += v.toObject()["text"].toString();
        }
    }
    // OpenRouter format: obj["choices"][0]["message"]["content"]
    else if (obj.contains("choices") && obj["choices"].isArray()) {
        QJsonArray arr = obj["choices"].toArray();
        if (!arr.isEmpty())
            content = arr[0].toObject()["message"].toObject()["content"].toString();
    }
    // Gemini format: obj["candidates"][0]["content"]["parts"][*]["text"] —
    // a candidate can also come back with no "parts" at all (blocked by a
    // safety filter, cut off by a finishReason other than a normal stop);
    // content just stays "" in that case and falls through to the generic
    // "(Empty response from server)" handling below rather than needing
    // its own special-cased message.
    else if (obj.contains("candidates") && obj["candidates"].isArray()) {
        QJsonArray candidates = obj["candidates"].toArray();
        if (!candidates.isEmpty()) {
            QJsonArray parts = candidates[0].toObject()["content"].toObject()["parts"].toArray();
            for (const QJsonValue &v : parts) {
                QJsonObject partObj = v.toObject();
                // Skip thought-summary parts. includeThoughts is left
                // unset above (defaults to false, no summaries requested),
                // but at least one model on this exact API is documented
                // to return thought-marked parts regardless of that
                // setting — the systemPrompt's "respond ONLY with raw
                // JSON" contract only holds for the real answer text; a
                // stray reasoning-summary part concatenated in front of it
                // would break every JSON.parse() downstream in AITab.qml.
                if (partObj["thought"].toBool()) continue;
                content += partObj["text"].toString();
            }
        }
    }

    if (content.isEmpty() && obj.contains("error")) {
        QString errMsg = obj["error"].toObject()["message"].toString();
        emit responseReceived(errMsg.isEmpty() ? "Unknown API error" : errMsg, true);
        return;
    }

    // FIX #27: a 200 response with no content blocks is not a success —
    // emit as error so the UI shows a red bubble rather than a blank one.
    if (content.isEmpty()) {
        emit responseReceived("(Empty response from server)", true);
        return;
    }

    emit responseReceived(content, false);
}
