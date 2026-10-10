#include "FileFilterModel.h"

#include <QQmlEngine>
#include <QUrl>

FileFilterModel::FileFilterModel(QObject *parent) : QSortFilterProxyModel(parent)
{
    setFilterCaseSensitivity(Qt::CaseInsensitive);
    connect(this, &QAbstractItemModel::rowsInserted, this, &FileFilterModel::countChanged);
    connect(this, &QAbstractItemModel::rowsRemoved, this, &FileFilterModel::countChanged);
    connect(this, &QAbstractItemModel::modelReset, this, &FileFilterModel::countChanged);
}

void FileFilterModel::setSourceModel(QAbstractItemModel *model)
{
    QSortFilterProxyModel::setSourceModel(model);
    if (model) setFilterRole(model->roleNames().key(QByteArrayLiteral("fileName"), Qt::DisplayRole));
    emit countChanged();
}

void FileFilterModel::setSearchText(const QString &text)
{
    if (m_searchText == text) return;
    m_searchText = text;
    // Fixed-string matching treats [, *, and ? as literal filename characters.
    setFilterFixedString(text);
    emit searchTextChanged();
}

QVariant FileFilterModel::get(int row, const QString &role) const
{
    if (row < 0 || row >= rowCount()) return {};
    const auto roles = roleNames();
    const int key = roles.key(role.toUtf8(), -1);
    return key < 0 ? QVariant() : data(index(row, 0), key);
}

bool FileFilterModel::isFolder(int row) const
{
    return get(row, QStringLiteral("fileIsDir")).toBool();
}

void FileFilterModel::refresh()
{
    if (!sourceModel()) return;
    // FolderListModel has no refresh invokable; changing its folder schedules
    // a new directory read. Restore it immediately, preserving QML's binding.
    const QVariant folder = sourceModel()->property("folder");
    sourceModel()->setProperty("folder", QUrl());
    sourceModel()->setProperty("folder", folder);
}

static const int fileFilterRegistration = qmlRegisterType<FileFilterModel>(
    "macdowsOS.Locations", 1, 0, "FileFilterModel");
