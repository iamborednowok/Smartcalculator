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
    // Anthropic direct key (optional — used as vision fallback in AITab)
    Q_PROPERTY(QString anthKey READ anthKey WRITE setAnthKey NOTIFY anthKeyChanged)

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

    bool darkMode()  const;
    void setDarkMode(bool v);

    bool fracMode()  const;
    void setFracMode(bool v);

    bool sciMode()   const;
    void setSciMode(bool v);

signals:
    void orKeyChanged();
    void anthKeyChanged();
    void darkModeChanged();
    void fracModeChanged();
    void sciModeChanged();
};
