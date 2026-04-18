#include "AppSettings.h"
#include <QSettings>

// ── helpers ───────────────────────────────────────────────────────────────────

static QSettings& cfg()
{
    // Static local — one QSettings instance per process.
    static QSettings s(QStringLiteral("SmartCalc"), QStringLiteral("SmartCalc"));
    return s;
}

// ── ctor ─────────────────────────────────────────────────────────────────────

AppSettings::AppSettings(QObject *parent) : QObject(parent) {}

// ── orKey ─────────────────────────────────────────────────────────────────────

QString AppSettings::orKey() const
{
    return cfg().value(QStringLiteral("api/orKey"), QString{}).toString();
}
void AppSettings::setOrKey(const QString &v)
{
    if (v == orKey()) return;
    cfg().setValue(QStringLiteral("api/orKey"), v);
    emit orKeyChanged();
}

// ── anthKey ───────────────────────────────────────────────────────────────────

QString AppSettings::anthKey() const
{
    return cfg().value(QStringLiteral("api/anthKey"), QString{}).toString();
}
void AppSettings::setAnthKey(const QString &v)
{
    if (v == anthKey()) return;
    cfg().setValue(QStringLiteral("api/anthKey"), v);
    emit anthKeyChanged();
}

// ── darkMode ─────────────────────────────────────────────────────────────────

bool AppSettings::darkMode() const
{
    return cfg().value(QStringLiteral("ui/darkMode"), true).toBool();
}
void AppSettings::setDarkMode(bool v)
{
    if (v == darkMode()) return;
    cfg().setValue(QStringLiteral("ui/darkMode"), v);
    emit darkModeChanged();
}

// ── fracMode ─────────────────────────────────────────────────────────────────

bool AppSettings::fracMode() const
{
    return cfg().value(QStringLiteral("calc/fracMode"), false).toBool();
}
void AppSettings::setFracMode(bool v)
{
    if (v == fracMode()) return;
    cfg().setValue(QStringLiteral("calc/fracMode"), v);
    emit fracModeChanged();
}

// ── sciMode ──────────────────────────────────────────────────────────────────

bool AppSettings::sciMode() const
{
    return cfg().value(QStringLiteral("calc/sciMode"), false).toBool();
}
void AppSettings::setSciMode(bool v)
{
    if (v == sciMode()) return;
    cfg().setValue(QStringLiteral("calc/sciMode"), v);
    emit sciModeChanged();
}
