#include "ApiClient.h"
#include <QNetworkRequest>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QUrl>

static constexpr int REQUEST_TIMEOUT_MS = 15000;  // 15 s

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
                          const QString &apiKey,
                          const QString &model)
{
    if (m_loading) return;

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

    if (apiKey.isEmpty()) {
        req.setUrl(QUrl("https://api.anthropic.com/v1/messages"));
        req.setRawHeader("x-api-key", "");
        req.setRawHeader("anthropic-version", "2023-06-01");
        body["model"]      = model;
        body["max_tokens"] = 1000;
        body["system"]     = systemPrompt;
        body["messages"]   = msgArray;
    } else {
        req.setUrl(QUrl("https://openrouter.ai/api/v1/chat/completions"));
        req.setRawHeader("Authorization", ("Bearer " + apiKey).toUtf8());
        req.setRawHeader("HTTP-Referer",  "https://smartcalc.app");

        QJsonObject sysMsg;
        sysMsg["role"]    = "system";
        sysMsg["content"] = systemPrompt;
        QJsonArray full;
        full.append(sysMsg);
        for (const QJsonValue &v : msgArray) full.append(v);

        body["model"]      = model;
        body["max_tokens"] = 1000;
        body["messages"]   = full;
    }

    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

    setLoading(true);
    m_reply = m_nam.post(req, QJsonDocument(body).toJson());
    connect(m_reply, &QNetworkReply::finished, this, &ApiClient::onReplyFinished);

    // FIX: start timeout watchdog — abort if server doesn't respond in 15 s
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

    if (m_reply->error() != QNetworkReply::NoError) {
        QString errMsg = m_reply->error() == QNetworkReply::OperationCanceledError
                         ? "Request timed out (15 s)"
                         : m_reply->errorString();
        emit responseReceived(errMsg, true);
        m_reply = nullptr;
        return;
    }

    QByteArray data = m_reply->readAll();
    m_reply = nullptr;

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
