#pragma once

#include <QAbstractListModel>
#include <QUrl>
#include <QVariantList>

class FileLocations final : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(QAbstractListModel *sidebarModel READ sidebarModel CONSTANT)

public:
    explicit FileLocations(QObject *parent = nullptr);

    QAbstractListModel *sidebarModel();
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;
    Q_INVOKABLE QVariantList sidebarLocations() const;
    Q_INVOKABLE QString homeUrl() const;
    Q_INVOKABLE QString normalizeFolder(const QString &value) const;
    Q_INVOKABLE QString labelForUrl(const QUrl &url) const;

private:
    QVariantList discoverLocations() const;
    QVariantList m_locations;
};
