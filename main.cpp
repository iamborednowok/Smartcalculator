#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include "backend/MathEngine.h"
#include "backend/AppSettings.h"
#include "backend/ApiClient.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setOrganizationName("SmartCalc");
    app.setApplicationName("SmartCalc");
    app.setApplicationVersion("1.0");

    // Register C++ types accessible from QML
    qmlRegisterType<MathEngine>("SmartCalc.Backend", 1, 0, "MathEngine");
    qmlRegisterType<AppSettings>("SmartCalc.Backend", 1, 0, "AppSettings");
    qmlRegisterType<ApiClient>("SmartCalc.Backend", 1, 0, "ApiClient");

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
