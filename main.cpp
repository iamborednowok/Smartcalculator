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
#include "backend/FileHelper.h"
#include "backend/HapticHelper.h"

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

// ── Format a QQmlError into a readable block ──────────────────────────────────

static QString formatError(int index, const QQmlError &err)
{
    QString header = QString("── Error %1 ").arg(index);
    header += QString("─").repeated(qMax(0, 42 - header.length()));

    // Trim the URL to "qml/..." so it fits on screen
    QString url = err.url().toString();
    int qmlIdx  = url.indexOf("/qml/");
    QString shortUrl = (qmlIdx >= 0) ? url.mid(qmlIdx + 1) : url;

    return header + "\n"
         + "File:    " + shortUrl + "\n"
         + "Line:    " + (err.line()   > 0 ? QString::number(err.line())   : "?") + "\n"
         + "Column:  " + (err.column() > 0 ? QString::number(err.column()) : "?") + "\n"
         + "Message: " + err.description() + "\n";
}

// ── Fallback error screen ─────────────────────────────────────────────────────

static const char *ERROR_SCREEN_QML = R"QMLSRC(
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

ApplicationWindow {
    visible: true
    width:   400
    height:  820
    title:   "SmartCalc — Startup Error"

    background: Rectangle { color: "#010208" }

    // Hidden TextEdit used as clipboard bridge.
    // Qt.application.clipboard does not exist in QML; this is the correct pattern.
    TextEdit {
        id:      clipBridge
        visible: false
        function copyText(s) {
            text = s
            selectAll()
            copy()
            text = ""
        }
    }

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

                // TextEdit (read-only) so the user can also long-press select manually
                TextEdit {
                    width:             parent.width
                    text:              typeof errorLog !== "undefined"
                                           ? errorLog
                                           : "(no error details captured)"
                    color:             "#ff7070"
                    font.pixelSize:    11
                    font.family:       "monospace"
                    wrapMode:          TextEdit.WrapAnywhere
                    readOnly:          true
                    selectByMouse:     true
                    selectionColor:    Qt.rgba(0.49, 0.23, 0.93, 0.45)
                    selectedTextColor: "#ffffff"
                }
            }
        }

        Text {
            text:             "📁 " + (typeof logPath !== "undefined" ? logPath : "")
            color:            "#44446a"
            font.pixelSize:   10
            wrapMode:         Text.WrapAnywhere
            Layout.fillWidth: true
        }

        Rectangle {
            Layout.fillWidth: true
            height:  50
            radius:  12
            color:   copyArea.pressed ? "#5b21b6" : "#7C3AED"
            Behavior on color { ColorAnimation { duration: 80 } }

            Text {
                anchors.centerIn: parent
                text:  copyDone.visible ? "✓  Copied!" : "📋  Copy Error"
                color: "white"
                font.pixelSize: 14
                font.bold:      true
            }

            MouseArea {
                id: copyArea
                anchors.fill: parent
                onClicked: {
                    var report = "=== SmartCalc Error Report ===\n"
                               + "Time: " + new Date().toString() + "\n"
                               + "Log:  " + (typeof logPath !== "undefined" ? logPath : "n/a") + "\n"
                               + "==============================\n\n"
                               + (typeof errorLog !== "undefined" ? errorLog : "(none)")
                    clipBridge.copyText(report)
                    copyDone.visible = true
                    hideTimer.restart()
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
            Timer { id: hideTimer; interval: 2500; onTriggered: copyDone.visible = false }
        }

        Item { Layout.fillHeight: true; Layout.preferredHeight: 1 }
    }
}
)QMLSRC";

// ── main ─────────────────────────────────────────────────────────────────────

int main(int argc, char *argv[])
{
    installMessageHandler();

    QGuiApplication app(argc, argv);
    app.setOrganizationName("SmartCalc");
    app.setApplicationName("SmartCalc");
    app.setApplicationVersion("1.2");

    writeLog("=== SmartCalc starting — v" + app.applicationVersion() + " ===");
    writeLog("Log file: " + logFilePath());

    QQmlApplicationEngine engine;

    QList<QQmlError> collectedErrors;

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::warnings,
        &app,
        [&collectedErrors](const QList<QQmlError> &warnings) {
            for (const QQmlError &err : warnings) {
                writeLog("QML WARNING: " + err.toString());
                collectedErrors << err;
            }
        });

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
                QStringList blocks;
                for (int i = 0; i < collectedErrors.size(); ++i)
                    blocks << formatError(i + 1, collectedErrors[i]);
                errorText = QString("Total errors: %1\n\n").arg(collectedErrors.size())
                          + blocks.join("\n");
            }

            engine.rootContext()->setContextProperty("errorLog", errorText);
            engine.rootContext()->setContextProperty("logPath",  logFilePath());
            engine.loadData(QByteArray(ERROR_SCREEN_QML));
        },
        Qt::QueuedConnection);

    writeLog("Loading QML root via module: SmartCalc.Backend / main");
    engine.loadFromModule("SmartCalc.Backend", "Main");

    int exitCode = app.exec();
    writeLog("=== SmartCalc exited with code " + QString::number(exitCode) + " ===");
    return exitCode;
}
