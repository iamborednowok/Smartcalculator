#pragma once
#include <QObject>
#include <QJSEngine>
#include <QString>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

class MathEngine : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit MathEngine(QObject *parent = nullptr);

    // Evaluate a math expression string, returns result as string
    Q_INVOKABLE QString evaluate(const QString &expression, bool degrees = true, bool fracMode = false);

    // Evaluate a graph expression f(x) — sandboxed, no raw eval in QML
    Q_INVOKABLE double evaluateAt(const QString &expression, double x);

    // PERF: batched sibling to evaluateAt() — see MathEngine.cpp for why.
    // Evaluates one expression at `steps+1` evenly-spaced x values between
    // xStart and xEnd (inclusive) in a single native call. Same GParser,
    // same per-point math and NaN-on-error behavior as evaluateAt(); this
    // just amortizes expression.simplified() once instead of per-sample
    // and collapses `steps+1` separate QML→C++ calls into one. Used by
    // GraphTab's Canvas.onPaint plot loop instead of calling evaluateAt()
    // once per horizontal pixel.
    Q_INVOKABLE QVariantList evaluateRange(const QString &expression, double xStart, double xEnd, int steps);

    // Format result number nicely
    Q_INVOKABLE QString formatNumber(double value) const;

    // Convert units
    Q_INVOKABLE double convertUnit(double value,
                                   const QString &fromUnit,
                                   const QString &toUnit,
                                   const QString &category) const;

private:
    QJSEngine m_engine;
    bool      m_degrees = true;   // mirrors last degrees flag passed to evaluate()

    void loadMathLibrary();
    QString prepareExpression(const QString &raw, bool degrees) const;
};
