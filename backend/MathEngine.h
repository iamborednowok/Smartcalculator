#pragma once
#include <QObject>
#include <QJSEngine>
#include <QString>

class MathEngine : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit MathEngine(QObject *parent = nullptr);

    // Evaluate a math expression string, returns result as string
    Q_INVOKABLE QString evaluate(const QString &expression, bool degrees = true, bool fracMode = false);

    // Format result number nicely
    Q_INVOKABLE QString formatNumber(double value) const;

    // Convert units
    Q_INVOKABLE double convertUnit(double value,
                                   const QString &fromUnit,
                                   const QString &toUnit,
                                   const QString &category) const;

private:
    QJSEngine m_engine;

    void loadMathLibrary();
    QString prepareExpression(const QString &raw, bool degrees) const;
};
