#pragma once
#include <QObject>
#include <QSettings>
#include <QtQml/qqmlregistration.h>

class AppSettings : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool darkMode  READ darkMode  WRITE setDarkMode  NOTIFY darkModeChanged)
    Q_PROPERTY(QString lang   READ lang      WRITE setLang      NOTIFY langChanged)
    Q_PROPERTY(QString orKey  READ orKey     WRITE setOrKey     NOTIFY orKeyChanged)
    Q_PROPERTY(QString hfToken READ hfToken  WRITE setHfToken   NOTIFY hfTokenChanged)

public:
    explicit AppSettings(QObject *parent = nullptr);

    bool    darkMode() const;
    QString lang()     const;
    QString orKey()    const;
    QString hfToken()  const;

    void setDarkMode(bool v);
    void setLang(const QString &v);
    void setOrKey(const QString &v);
    void setHfToken(const QString &v);

    Q_INVOKABLE QString get(const QString &key, const QString &def = {}) const;
    Q_INVOKABLE void    set(const QString &key, const QString &value);
    Q_INVOKABLE void    remove(const QString &key);

signals:
    void darkModeChanged();
    void langChanged();
    void orKeyChanged();
    void hfTokenChanged();

private:
    QSettings m_settings;
};
