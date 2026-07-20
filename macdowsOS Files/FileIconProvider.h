#pragma once

#include <QQuickImageProvider>

// Bridges QML Image to the native Windows/Qt file icon provider.
// Folder icons are handled by the bundled visual theme; this provider is used
// for regular files so DLL/LOG/XML/etc. match Explorer's associations.
class FileIconProvider final : public QQuickImageProvider
{
public:
    FileIconProvider();

    QPixmap requestPixmap(const QString &id, QSize *size, const QSize &requestedSize) override;
};
