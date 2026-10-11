#pragma once

#include <QObject>
#include <QSet>
#include <QString>

class QQmlEngine;
class QQuickWindow;

class WindowManager final : public QObject
{
    Q_OBJECT
public:
    explicit WindowManager(QQmlEngine *engine, QObject *parent = nullptr);
    Q_INVOKABLE bool openWindow(const QString &path = QString());
    Q_INVOKABLE void releaseWindow(QQuickWindow *window);
private:
    QQmlEngine *m_engine;
    QSet<QQuickWindow *> m_windows;
};
