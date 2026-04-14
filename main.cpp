#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
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
    QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dir);
    return dir + "/crash_log.txt";
}

static void writeLog(const QString &message)
{
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
        QByteArray localMsg = msg.toLocal8Bit();
        switch (type) {
        case QtDebugMsg:
            fprintf(stderr, "D [SmartCalc] %s (%s:%u)\n", localMsg.constData(), ctx.file, ctx.line); break;
        case QtInfoMsg:
            fprintf(stderr, "I [SmartCalc] %s (%s:%u)\n", localMsg.constData(), ctx.file, ctx.line); break;
        case QtWarningMsg:
            fprintf(stderr, "W [SmartCalc] %s (%s:%u)\n", localMsg.constData(), ctx.file, ctx.line); break;
        case QtCriticalMsg:
            fprintf(stderr, "E [SmartCalc] %s (%s:%u)\n", localMsg.constData(), ctx.file, ctx.line); break;
        case QtFatalMsg:
            fprintf(stderr, "F [SmartCalc] %s (%s:%u)\n", localMsg.constData(), ctx.file, ctx.line);
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

// ── Fallback error screen ─────────────────────────────────────────────────────
// Loaded via engine.loadData() when objectCreationFailed fires.
// Uses only core Qt imports — no SmartCalc.Backend — so it always works.
// Error text is injected via rootContext properties (never string-interpolated).

static const char *ERROR_SCREEN_QML = R"QML(
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

ApplicationWindow {
    visible: true
    width:   400
    height:  820
    title:   "SmartCalc — Startup Error"

    background: Rectangle { color: "#010208" }

    ColumnLayout {
        anchors.fill:    parent
        anchors.margins: 28
        spacing:         18

        Item { Layout.fillHeight: true; Layout.preferredHeight: 1 }

        Text {
            text:             "⚠️"
            font.pixelSize:   52
            Layout.alignment: Qt.AlignHCenter
        }

        Text {
            text:             "UI Failed to Initialize"
            color:            "#f0f0ff"
            font.pixelSize:   22
            font.bold:        true
            Layout.alignment: Qt.AlignHCenter
        }

        Text {
            text:                "SmartCalc loaded, but its interface could not start.\n"
                               + "No data was lost. See the error details below."
            color:               "#8888cc"
            font.pixelSize:      13
            wrapMode:            Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth:    true
        }

        // Error detail box
        Rectangle {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            color:             Qt.rgba(1, 0.18, 0.18, 0.07)
            border.color:      Qt.rgba(1, 0.3, 0.3, 0.35)
            radius:            14

            ScrollView {
                anchors.fill:    parent
                anchors.margins: 14
                clip:            true
                Text {
                    // errorLog is set by main.cpp via rootContext property
                    text:            typeof errorLog !== "undefined"
                                         ? errorLog
                                         : "(no error details captured)"
                    color:           "#ff7070"
                    font.pixelSize:  11
                    font.family:     "monospace"
                    wrapMode:        Text.WrapAnywhere
                    width:           parent.width
                }
            }
        }

        // Log file path hint
        Text {
            text:             "📁 " + (typeof logPath !== "undefined" ? logPath : "")
            color:            "#44446a"
            font.pixelSize:   10
            wrapMode:         Text.WrapAnywhere
            Layout.fillWidth: true
        }

        // Copy button
        Rectangle {
            Layout.fillWidth: true
            height:  50
            radius:  12
            color:   copyArea.pressed ? "#5b21b6" : "#7C3AED"
            Behavior on color { ColorAnimation { duration: 80 } }

            Text {
                anchors.centerIn: parent
                text:  "📋  Copy Error"
                color: "white"
                font.pixelSize: 14
                font.bold:      true
            }

            MouseArea {
                id: copyArea
                anchors.fill: parent
                onClicked: {
                    var report = "[SmartCalc Crash Report]\n"
                               + "Time: " + new Date().toString() + "\n\n"
                               + (typeof errorLog !== "undefined" ? errorLog : "(none)") + "\n\n"
                               + "Log: " + (typeof logPath !== "undefined" ? logPath : "");
                    if (Qt.application.clipboard)
                        Qt.application.clipboard.setText(report);
                    copyDone.visible = true;
                    hideTimer.start();
                }
            }
        }

        Text {
            id:               copyDone
            visible:          false
            text:             "✓ Copied to clipboard"
            color:            "#7C3AED"
            font.pixelSize:   12
            Layout.alignment: Qt.AlignHCenter
            Timer { id: hideTimer; interval: 2000; onTriggered: copyDone.visible = false }
        }

        Item { Layout.fillHeight: true; Layout.preferredHeight: 1 }
    }
}
)QML";

// ── main ─────────────────────────────────────────────────────────────────────

int main(int argc, char *argv[])
{
    installMessageHandler();

    QGuiApplication app(argc, argv);
    app.setOrganizationName("SmartCalc");
    app.setApplicationName("SmartCalc");
    app.setApplicationVersion("1.0");

    writeLog("=== SmartCalc starting — v" + app.applicationVersion() + " ===");
    writeLog("Log file: " + logFilePath());

    QQmlApplicationEngine engine;

    // Collect every QML warning emitted during loading.
    // Qt emits warnings() synchronously, before objectCreationFailed, so this
    // list is fully populated by the time the failure handler runs.
    QStringList collectedErrors;

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::warnings,
        &app,
        [&collectedErrors](const QList<QQmlError> &warnings) {
            for (const QQmlError &err : warnings) {
                writeLog("QML WARNING: " + err.toString());
                collectedErrors << err.toString();
            }
        });

    // On failure: show the error screen instead of closing the app.
    //
    // Qt::QueuedConnection is required — objectCreationFailed fires from inside
    // engine.loadFromModule() while the loader is still unwinding. Calling
    // engine.loadData() synchronously here would re-enter the engine. Queuing
    // defers the call to the next event-loop tick when the engine is idle.
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        [&engine, &collectedErrors]() {

            writeLog("UI init failed — showing error screen (app stays open).");

            QString errorText;
            if (collectedErrors.isEmpty()) {
                errorText =
                    "No QML warnings were captured.\n\n"
                    "Possible causes:\n"
                    "  • Missing Qt .so libraries in APK\n"
                    "  • libSmartCalcplugin.so not deployed\n"
                    "  • ABI mismatch (arm64 vs x86_64)\n"
                    "  • QML import path not set correctly\n\n"
                    "Run:  adb logcat -s Qt,SmartCalc";
            } else {
                errorText = collectedErrors.join("\n\n");
            }

            // Inject via context properties — no string escaping needed.
            // These are readable in QML as plain identifiers (errorLog, logPath).
            engine.rootContext()->setContextProperty("errorLog", errorText);
            engine.rootContext()->setContextProperty("logPath",  logFilePath());

            // Load the fallback screen. It only imports QtQuick and
            // QtQuick.Controls.Basic, so it works even when SmartCalc.Backend
            // is the thing that broke.
            engine.loadData(QByteArray(ERROR_SCREEN_QML));
        },
        Qt::QueuedConnection);

    writeLog("Loading QML root via module: SmartCalc.Backend / main");
    engine.loadFromModule("SmartCalc.Backend", "main");

    int exitCode = app.exec();
    writeLog("=== SmartCalc exited with code " + QString::number(exitCode) + " ===");
    return exitCode;
}
