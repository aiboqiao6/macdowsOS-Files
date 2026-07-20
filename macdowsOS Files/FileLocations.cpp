#include "FileLocations.h"

#include <QDir>
#include <QDesktopServices>
#include <QFileInfo>
#include <QGuiApplication>
#include <QClipboard>
#include <QQmlEngine>
#include <QJSEngine>
#include <QStandardPaths>
#include <QStorageInfo>

namespace {
// Keep each sidebar entry in one QVariantMap so the C++ model and QML
// delegate share the same role names and do not need parallel structures.
QVariantMap item(const QString &name, const QString &path, const QString &icon, const QString &section,
                const QVariantMap &extra = {})
{
    QVariantMap result = extra;
    result.insert(QStringLiteral("name"), name);
    result.insert(QStringLiteral("path"), QUrl::fromLocalFile(path).toString());
    result.insert(QStringLiteral("icon"), icon);
    result.insert(QStringLiteral("section"), section);
    return result;
}
}

FileLocations::FileLocations(QObject *parent) : QAbstractListModel(parent), m_locations(discoverLocations()) {}

QVariantList FileLocations::discoverLocations() const
{
    QVariantList result;

    // Personal locations come from Windows' standard user folders. Missing
    // folders are skipped so the sidebar reflects the current machine.
    const QString home = QStandardPaths::writableLocation(QStandardPaths::HomeLocation);
    if (!home.isEmpty() && QDir(home).exists())
        result << item(tr("Home"), home, QStringLiteral("home"), QStringLiteral("\u4E2A\u4EBA\u6536\u85CF"));

    const auto addFolder = [&result](const QString &name, QStandardPaths::StandardLocation location,
                                     const QString &icon) {
        const QString path = QStandardPaths::writableLocation(location);
        if (!path.isEmpty() && QDir(path).exists())
            result << item(name, path, icon, QStringLiteral("\u4E2A\u4EBA\u6536\u85CF"));
    };
    addFolder(tr("Desktop"), QStandardPaths::DesktopLocation, QStringLiteral("desktop"));
    addFolder(tr("Documents"), QStandardPaths::DocumentsLocation, QStringLiteral("document"));
    addFolder(tr("Downloads"), QStandardPaths::DownloadLocation, QStringLiteral("download"));
    addFolder(tr("Pictures"), QStandardPaths::PicturesLocation, QStringLiteral("picture"));
    addFolder(tr("Music"), QStandardPaths::MusicLocation, QStringLiteral("music"));
    addFolder(tr("Videos"), QStandardPaths::MoviesLocation, QStringLiteral("video"));

    // Volumes are discovered at runtime instead of being hard-coded. This
    // keeps USB and secondary drives in sync with the Windows file manager.
    for (const QFileInfo &drive : QDir::drives()) {
        const QString root = QDir::cleanPath(drive.absoluteFilePath());
        QStorageInfo storage(root);
        QString volumeName = storage.isValid() ? storage.displayName() : QString();
        if (volumeName.isEmpty()) volumeName = root;
        const QString driveLetter = root.left(2).toUpper();
        if (!volumeName.contains(driveLetter, Qt::CaseInsensitive))
            volumeName += QStringLiteral(" (") + driveLetter + QStringLiteral(")");
        QVariantMap extra;
        if (storage.isValid()) {
            extra.insert(QStringLiteral("totalBytes"), static_cast<qlonglong>(storage.bytesTotal()));
            extra.insert(QStringLiteral("freeBytes"), static_cast<qlonglong>(storage.bytesAvailable()));
        }
        result << item(volumeName, root, QStringLiteral("drive"), QStringLiteral("\u4F4D\u7F6E"), extra);
    }
    return result;
}

QAbstractListModel *FileLocations::sidebarModel()
{
    return this;
}

int FileLocations::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_locations.size();
}

QVariant FileLocations::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_locations.size())
        return {};
    const QVariantMap values = m_locations.at(index.row()).toMap();
    // Role numbers are intentionally stable: QML consumes the names returned
    // by roleNames(), while Qt's display role remains useful to diagnostics.
    switch (role) {
    case Qt::DisplayRole:
    case Qt::UserRole + 1: return values.value(QStringLiteral("name"));
    case Qt::UserRole + 2: return values.value(QStringLiteral("path"));
    case Qt::UserRole + 3: return values.value(QStringLiteral("icon"));
    case Qt::UserRole + 4: return values.value(QStringLiteral("section"));
    case Qt::UserRole + 5: return values.value(QStringLiteral("totalBytes"));
    case Qt::UserRole + 6: return values.value(QStringLiteral("freeBytes"));
    default: return {};
    }
}

QHash<int, QByteArray> FileLocations::roleNames() const
{
    return {{Qt::UserRole + 1, "name"}, {Qt::UserRole + 2, "path"}, {Qt::UserRole + 3, "icon"},
            {Qt::UserRole + 4, "section"}, {Qt::UserRole + 5, "totalBytes"}, {Qt::UserRole + 6, "freeBytes"}};
}

QVariantList FileLocations::sidebarLocations() const
{
    return m_locations;
}

QString FileLocations::homeUrl() const
{
    const QString home = QStandardPaths::writableLocation(QStandardPaths::HomeLocation);
    return QUrl::fromLocalFile(home).toString();
}

QString FileLocations::normalizeFolder(const QString &value) const
{
    const QString text = value.trimmed();
    if (text.isEmpty()) return {};
    const QUrl candidate(text);
    const QString localPath = candidate.isLocalFile() ? candidate.toLocalFile() : QDir::fromNativeSeparators(text);
    const QFileInfo info(QDir::cleanPath(localPath));
    if (!info.exists() || !info.isDir()) return {};
    return QUrl::fromLocalFile(info.absoluteFilePath()).toString();
}

QString FileLocations::labelForUrl(const QUrl &url) const
{
    const QFileInfo info(url.toLocalFile());
    if (info.fileName().isEmpty()) return QDir::toNativeSeparators(info.absoluteFilePath());
    return info.fileName();
}

void FileLocations::copyToClipboard(const QString &text) const
{
    if (!QGuiApplication::clipboard())
        return;

    // QML uses file:/// URLs for navigation; users expect a native Windows
    // path when copying from the context menu.
    const QUrl candidate(text);
    const QString clipboardText = candidate.isLocalFile()
        ? QDir::toNativeSeparators(candidate.toLocalFile())
        : text;
    QGuiApplication::clipboard()->setText(clipboardText);
}

bool FileLocations::revealInFileManager(const QString &value) const
{
    const QUrl candidate(value);
    const QString localPath = candidate.isLocalFile() ? candidate.toLocalFile() : QDir::fromNativeSeparators(value);
    const QFileInfo info(localPath);
    if (!info.exists())
        return false;

    // Explorer opens the directory itself for folders and the containing
    // directory for regular files.
    const QString folder = info.isDir() ? info.absoluteFilePath() : info.absolutePath();
    return QDesktopServices::openUrl(QUrl::fromLocalFile(folder));
}

// Register once during static initialization so every QML component can use
// `import macdowsOS.Locations 1.0` without manually passing an object around.
static const int fileLocationsRegistration = [] {
    qmlRegisterSingletonType<FileLocations>("macdowsOS.Locations", 1, 0, "FileLocations",
        [](QQmlEngine *, QJSEngine *) -> QObject * { return new FileLocations; });
    return 0;
}();
