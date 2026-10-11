#pragma once

#include <QObject>
#include <QString>

// Per-user filesystem folder/drive associations. The alternate roots let tests
// exercise real registry semantics without changing the user's associations.
class WindowsIntegration final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool enabled READ enabled NOTIFY stateChanged)
    Q_PROPERTY(bool canRestore READ canRestore NOTIFY stateChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY stateChanged)
public:
    explicit WindowsIntegration(QObject *parent = nullptr);
    WindowsIntegration(const QString &classesRoot, const QString &backupFile, QObject *parent = nullptr);
    bool enabled() const;
    bool canRestore() const;
    QString lastError() const { return m_lastError; }
    Q_INVOKABLE bool setEnabled(bool enabled);
    Q_INVOKABLE void refresh() { emit stateChanged(); }
private:
    bool install();
    bool restore();
    QString m_classesRoot;
    QString m_backupFile;
    QString m_lastError;
signals:
    void stateChanged();
};
