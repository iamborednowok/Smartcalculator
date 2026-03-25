#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include "backend/MathEngine.h"
#include "backend/AppSettings.h"
#include "backend/ApiClient.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setOrganizationName("SmartCalc");
    app.setApplicationName("SmartCalc");
    app.setApplicationVersion("1.0");

    // Types are auto-registered via QML_ELEMENT + qt_add_qml_module (URI SmartCalc.Backend).
    // Do NOT also call qmlRegisterType() here — double-registration causes warnings and
    // can silently shadow the CMake-generated plugin, breaking import path resolution.

    QQmlApplicationEngine engine;

    const QUrl url(QStringLiteral("qrc:/SmartCalc/qml/main.qml"));
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.load(url);
    return app.exec();
}
