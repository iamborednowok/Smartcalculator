#pragma once
#include <QObject>
#include <qqml.h>

// HapticHelper — fires a light tactile click on Android (no-op on other platforms).
// Registered as a singleton QML element in SmartCalc.Backend 1.0.
// Usage in QML:  HapticHelper.click()   or   HapticHelper.heavy()
class HapticHelper : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit HapticHelper(QObject *parent = nullptr);

    // Light click — use on every button press
    Q_INVOKABLE void click();

    // Heavier thud — use on = and C
    Q_INVOKABLE void heavy();
};
