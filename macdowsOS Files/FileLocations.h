#pragma once

#include <QAbstractListModel>
#include <QUrl>
#include <QVariantList>

// Native filesystem adapter exposed to QML as the FileLocations singleton.
// It owns the left sidebar model and provides the small set of filesystem
// operations that cannot be implemented safely in QML alone.
class FileLocations final : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(QAbstractListModel *sidebarModel READ sidebarModel CONSTANT)

public:
    explicit FileLocations(QObject *parent = nullptr);

    // QAbstractListModel implementation used by SidebarList.qml.
    QAbstractListModel *sidebarModel();
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;
    // QML-facing helpers used by navigation and the context menu.
    Q_INVOKABLE QVariantList sidebarLocations() const;
    Q_INVOKABLE QString homeUrl() const;
    Q_INVOKABLE QString normalizeFolder(const QString &value) const;
    Q_INVOKABLE QString labelForUrl(const QUrl &url) const;
    Q_INVOKABLE void copyToClipboard(const QString &text) const;
    Q_INVOKABLE bool revealInFileManager(const QString &value) const;

private:
    QVariantList discoverLocations() const;
    QVariantList m_locations;
};
