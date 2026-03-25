#include "AppSettings.h"

AppSettings::AppSettings(QObject *parent)
    : QObject(parent), m_settings("SmartCalc", "SmartCalc")
{}

bool    AppSettings::darkMode() const { return m_settings.value("darkMode", true).toBool(); }
QString AppSettings::lang()     const { return m_settings.value("lang", "en").toString(); }
QString AppSettings::orKey()    const { return m_settings.value("orKey", "").toString(); }
QString AppSettings::hfToken()  const { return m_settings.value("hfToken", "").toString(); }

void AppSettings::setDarkMode(bool v) {
    if (darkMode() == v) return;
    m_settings.setValue("darkMode", v);
    emit darkModeChanged();
}
void AppSettings::setLang(const QString &v) {
    if (lang() == v) return;
    m_settings.setValue("lang", v);
    emit langChanged();
}
void AppSettings::setOrKey(const QString &v) {
    m_settings.setValue("orKey", v);
    emit orKeyChanged();
}
void AppSettings::setHfToken(const QString &v) {
    m_settings.setValue("hfToken", v);
    emit hfTokenChanged();
}

QString AppSettings::get(const QString &key, const QString &def) const {
    return m_settings.value(key, def).toString();
}
void AppSettings::set(const QString &key, const QString &value) {
    m_settings.setValue(key, value);
}
void AppSettings::remove(const QString &key) {
    m_settings.remove(key);
}
