#include "FileHelper.h"
#include <QFile>
#include <QUrl>
#include <QMimeDatabase>
#include <QFileInfo>
#include <QDir>
#include <QStandardPaths>
#include <QDebug>

FileHelper::FileHelper(QObject *parent) : QObject(parent) {}

static QString toLocalPath(const QString &fileUrl)
{
    const QUrl u(fileUrl);
    // qrc:/foo/bar -> :/foo/bar — the form QFile/QFileInfo actually
    // understand for bundled resources. Handled via QUrl::path() (not a
    // hand-sliced substring) so it's correct regardless of how many
    // slashes follow the scheme. Added for readTextFile() below; the
    // other methods here only ever see file:// URIs from a native file
    // picker today, but there's no reason they shouldn't also work
    // against a resource path.
    if (u.scheme() == QLatin1String("qrc"))
        return QLatin1Char(':') + u.path();
    return u.isLocalFile() ? u.toLocalFile() : fileUrl;
}

QString FileHelper::readFileAsBase64(const QString &fileUrl) const
{
    QFile f(toLocalPath(fileUrl));
    if (!f.open(QIODevice::ReadOnly)) return {};
    return QString::fromLatin1(f.readAll().toBase64());
}

QString FileHelper::readTextFile(const QString &fileUrl) const
{
    QFile f(toLocalPath(fileUrl));
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return {};
    return QString::fromUtf8(f.readAll());
}

bool FileHelper::writeTextFile(const QString &fileUrl, const QString &content) const
{
    const QString path = toLocalPath(fileUrl);
    // Defensive, same as logFilePath()'s QDir().mkpath(dir) in main.cpp —
    // appDataPath() below already creates the directory, but this method
    // does not assume every caller went through it first.
    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        qWarning() << "FileHelper::writeTextFile: could not open" << path << "for writing";
        return false;
    }
    const qint64 written = f.write(content.toUtf8());
    return written >= 0;
}

QString FileHelper::appDataPath(const QString &filename) const
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dir);
    return dir + QLatin1Char('/') + filename;
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
