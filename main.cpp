#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlError>
#include <QtDebug>
#include <QFile>
#include <QTextStream>
#include <QDateTime>
#include <QStandardPaths>
#include <QDir>
#include "backend/MathEngine.h"
#include "backend/AppSettings.h"
#include "backend/ApiClient.h"

// ── Crash log helpers ─────────────────────────────────────────────────────────

static QString logFilePath()
{
    // On Android this resolves to the app's external files dir (readable via adb pull)
    QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dir);
    return dir + "/crash_log.txt";
}

static void writeLog(const QString &message)
{
    // Mirror to logcat / Qt debug output so adb logcat also captures it
    qCritical().noquote() << "[SmartCalc]" << message;

    QFile f(logFilePath());
    if (f.open(QIODevice::Append | QIODevice::Text)) {
        QTextStream ts(&f);
        ts << QDateTime::currentDateTime().toString(Qt::ISODate)
           << "  " << message << "\n";
    }
}

static void installMessageHandler()
{
    qInstallMessageHandler([](QtMsgType type, const QMessageLogContext &ctx, const QString &msg) {
        // Forward everything to the default handler (logcat on Android)
        QByteArray localMsg = msg.toLocal8Bit();

        switch (type) {
        case QtDebugMsg:
            fprintf(stderr, "D [SmartCalc] %s (%s:%u)\n", localMsg.constData(), ctx.file, ctx.line);
            break;
        case QtInfoMsg:
            fprintf(stderr, "I [SmartCalc] %s (%s:%u)\n", localMsg.constData(), ctx.file, ctx.line);
            break;
        case QtWarningMsg:
            fprintf(stderr, "W [SmartCalc] %s (%s:%u)\n", localMsg.constData(), ctx.file, ctx.line);
            break;
        case QtCriticalMsg:
            fprintf(stderr, "E [SmartCalc] %s (%s:%u)\n", localMsg.constData(), ctx.file, ctx.line);
            break;
        case QtFatalMsg:
            fprintf(stderr, "F [SmartCalc] %s (%s:%u)\n", localMsg.constData(), ctx.file, ctx.line);
            // Write fatal errors to file before the process dies
            {
                QFile f(logFilePath());
                if (f.open(QIODevice::Append | QIODevice::Text)) {
                    QTextStream ts(&f);
                    ts << QDateTime::currentDateTime().toString(Qt::ISODate)
                       << "  FATAL: " << msg
                       << " (" << ctx.file << ":" << ctx.line << ")\n";
                }
            }
            abort();
        }
    });
}

// ── main ─────────────────────────────────────────────────────────────────────

int main(int argc, char *argv[])
{
    // Install message handler FIRST so every qDebug/qWarning/qCritical is captured
    installMessageHandler();

    QGuiApplication app(argc, argv);
    app.setOrganizationName("SmartCalc");
    app.setApplicationName("SmartCalc");
    app.setApplicationVersion("1.0");

    writeLog("=== SmartCalc starting — v" + app.applicationVersion() + " ===");
    writeLog("Log file: " + logFilePath());

    // Types are auto-registered via QML_ELEMENT + qt_add_qml_module (URI SmartCalc.Backend).
    // Do NOT also call qmlRegisterType() here — double-registration causes warnings and
    // can silently shadow the CMake-generated plugin, breaking import path resolution.

    QQmlApplicationEngine engine;

    // ── Capture QML warnings (import errors, binding failures, etc.) ──────────
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::warnings,
        &app,
        [](const QList<QQmlError> &warnings) {
            for (const QQmlError &err : warnings) {
                writeLog("QML WARNING: " + err.toString());
            }
        });

    // ── Handle load failure — log every detail before exiting ────────────────
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() {
            writeLog("FATAL: QML object creation failed.");
            writeLog("Common causes:");
            writeLog("  1. Missing Qt .so libraries in APK (run androiddeployqt)");
            writeLog("  2. SmartCalc.Backend plugin not deployed (libSmartCalcplugin.so missing)");
            writeLog("  3. ABI mismatch (arm64 vs x86_64)");
            writeLog("  4. QML import path not set correctly");
            writeLog("Check logcat: adb logcat -s Qt,SmartCalc");
            writeLog("Pull crash log: adb pull " + logFilePath());
            QCoreApplication::exit(-1);
        },
        Qt::QueuedConnection);

    const QUrl url(QStringLiteral("qrc:/SmartCalc/qml/main.qml"));
    writeLog("Loading QML root: " + url.toString());
    engine.load(url);

    int exitCode = app.exec();
    writeLog("=== SmartCalc exited with code " + QString::number(exitCode) + " ===");
    return exitCode;
}
