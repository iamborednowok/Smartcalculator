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
