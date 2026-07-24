#pragma once
#include <QObject>
#include <QString>
#include <qqml.h>

// FileHelper — registered as QML element "FileHelper" in SmartCalc.Backend 1.0
// Provides file I/O utilities needed by AITab's vision upload feature.
// Instantiate once in AITab: FileHelper { id: fileHelper }
class FileHelper : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit FileHelper(QObject *parent = nullptr);

    // Read the file at fileUrl (file:// URI or absolute path) and return its
    // contents as a Base64 string.  Returns "" on error.
    Q_INVOKABLE QString readFileAsBase64(const QString &fileUrl) const;

    // Read the file at fileUrl as plain UTF-8 text. Accepts the same
    // file:// / absolute-path forms as the rest of this class, plus
    // qrc:/... for bundled resources (e.g. ai-skills/skillviewer.md,
    // added as a Qt resource in CMakeLists.txt). Returns "" on error —
    // callers that need "file missing" vs. "file empty" to mean different
    // things should check fileSizeBytes() first.
    Q_INVOKABLE QString readTextFile(const QString &fileUrl) const;

    // Write text (UTF-8, overwriting any existing content) to fileUrl —
    // a real, writable path, unlike readTextFile's qrc:/ resources which
    // are read-only at runtime. Creates parent directories if needed, same
    // as main.cpp's logFilePath() does for the crash log. Returns whether
    // the write succeeded so QML can decide how much to care; used today
    // for AITab's local chat-history persistence (appDataPath() below
    // gives it a proper cross-platform path to write that to).
    Q_INVOKABLE bool writeTextFile(const QString &fileUrl, const QString &content) const;

    // Full path for `filename` inside this app's writable data directory
    // (QStandardPaths::AppDataLocation — same location main.cpp's
    // logFilePath() already uses for the crash log), creating that
    // directory first if it does not exist yet. Gives QML a proper,
    // per-platform-correct place to persist things locally without
    // needing Qt.labs.platform's StandardPaths just for this one need.
    Q_INVOKABLE QString appDataPath(const QString &filename) const;

    // Return the MIME type, e.g. "image/jpeg", "image/png", "application/pdf".
    // Falls back to "application/octet-stream" for unknown types.
    Q_INVOKABLE QString mimeTypeForFile(const QString &fileUrl) const;

    // File size in bytes.  Returns -1 if the file is not found.
    Q_INVOKABLE qint64 fileSizeBytes(const QString &fileUrl) const;

    // Just the filename component, e.g. "photo.jpg".
    Q_INVOKABLE QString fileName(const QString &fileUrl) const;

    // Human-readable size, e.g. "1.4 MB".
    Q_INVOKABLE QString humanSize(const QString &fileUrl) const;
};
