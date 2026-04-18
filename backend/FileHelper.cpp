#include "FileHelper.h"
#include <QFile>
#include <QUrl>
#include <QMimeDatabase>
#include <QFileInfo>

FileHelper::FileHelper(QObject *parent) : QObject(parent) {}

static QString toLocalPath(const QString &fileUrl)
{
    const QUrl u(fileUrl);
    return u.isLocalFile() ? u.toLocalFile() : fileUrl;
}

QString FileHelper::readFileAsBase64(const QString &fileUrl) const
{
    QFile f(toLocalPath(fileUrl));
    if (!f.open(QIODevice::ReadOnly)) return {};
    return QString::fromLatin1(f.readAll().toBase64());
}

QString FileHelper::mimeTypeForFile(const QString &fileUrl) const
{
    QMimeDatabase db;
    const QMimeType mt = db.mimeTypeForFile(toLocalPath(fileUrl));
    return mt.isValid() ? mt.name() : QStringLiteral("application/octet-stream");
}

qint64 FileHelper::fileSizeBytes(const QString &fileUrl) const
{
    return QFileInfo(toLocalPath(fileUrl)).size();
}

QString FileHelper::fileName(const QString &fileUrl) const
{
    return QFileInfo(toLocalPath(fileUrl)).fileName();
}

QString FileHelper::humanSize(const QString &fileUrl) const
{
    qint64 bytes = fileSizeBytes(fileUrl);
    if (bytes < 0)         return QStringLiteral("?");
    if (bytes < 1024)      return QString::number(bytes) + " B";
    if (bytes < 1048576)   return QString::number(bytes / 1024.0, 'f', 1) + " KB";
    return                        QString::number(bytes / 1048576.0, 'f', 1) + " MB";
}
