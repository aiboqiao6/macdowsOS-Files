#pragma once

#include <QSortFilterProxyModel>
#include <QString>

// Preserve FolderListModel's roles while filtering both files and directories.
class FileFilterModel : public QSortFilterProxyModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(QString searchText READ searchText WRITE setSearchText NOTIFY searchTextChanged)
public:
    explicit FileFilterModel(QObject *parent = nullptr);
    void setSourceModel(QAbstractItemModel *model) override;
    int count() const { return rowCount(); }
    QString searchText() const { return m_searchText; }
    void setSearchText(const QString &text);
    Q_INVOKABLE QVariant get(int row, const QString &role) const;
    Q_INVOKABLE bool isFolder(int row) const;
    Q_INVOKABLE void refresh();
signals:
    void countChanged();
    void searchTextChanged();
private:
    QString m_searchText;
};
