#pragma once
#include <QObject>
#include <QString>
#include <qqml.h>

// AppSettings — persists user preferences to QSettings.
// Registered as a QML element in SmartCalc.Backend 1.0.
// Instantiate once in Main.qml: AppSettings { id: settings }
class AppSettings : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    // ── API keys ──────────────────────────────────────────────────────
    // OpenRouter key (free tier unlocks Llama 3.3, Gemma 3, vision…)
    Q_PROPERTY(QString orKey   READ orKey   WRITE setOrKey   NOTIFY orKeyChanged)
    // Anthropic direct key (optional — powers text chat when no OpenRouter
    // key is set, and vision analysis in AITab either way). Previously
    // documented as "vision fallback" only, but ApiClient::sendToAI's
    // Anthropic branch already builds a complete request around it — it
    // just wasn't wired through. See ApiClient.cpp.
    Q_PROPERTY(QString anthKey READ anthKey WRITE setAnthKey NOTIFY anthKeyChanged)
    // Google AI Studio key (aistudio.google.com) for Gemini. Sits between
    // orKey and anthKey in ApiClient::sendToAI's priority — OpenRouter
    // first if set, then this, then the Anthropic fallback — since Gemini,
    // like OpenRouter's free lineup, has a genuine free tier rather than
    // being a last-resort paid fallback the way the Anthropic branch is
    // documented as being.
    Q_PROPERTY(QString geminiKey READ geminiKey WRITE setGeminiKey NOTIFY geminiKeyChanged)

    // ── Display / UX prefs ────────────────────────────────────────────
    Q_PROPERTY(bool darkMode  READ darkMode  WRITE setDarkMode  NOTIFY darkModeChanged)
    Q_PROPERTY(bool fracMode  READ fracMode  WRITE setFracMode  NOTIFY fracModeChanged)
    Q_PROPERTY(bool sciMode   READ sciMode   WRITE setSciMode   NOTIFY sciModeChanged)

public:
    explicit AppSettings(QObject *parent = nullptr);

    QString orKey()   const;
    void setOrKey(const QString &v);

    QString anthKey() const;
    void setAnthKey(const QString &v);

    QString geminiKey() const;
    void setGeminiKey(const QString &v);

    bool darkMode()  const;
    void setDarkMode(bool v);

    bool fracMode()  const;
    void setFracMode(bool v);

    bool sciMode()   const;
    void setSciMode(bool v);

signals:
    void orKeyChanged();
    void anthKeyChanged();
    void geminiKeyChanged();
    void darkModeChanged();
    void fracModeChanged();
    void sciModeChanged();
};
