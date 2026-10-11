#include "WindowManager.h"
#include "FileLocations.h"

#include <QCoreApplication>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickWindow>
#include <QTimer>
#include <QDebug>
#include <QScreen>

WindowManager::WindowManager(QQmlEngine *engine, QObject *parent)
    : QObject(parent), m_engine(engine) {}

bool WindowManager::openWindow(const QString &path)
{
    FileLocations locations;
    const QString folder = path.isEmpty() ? locations.homeUrl() : locations.normalizeFolder(path);
    if (folder.isEmpty()) return false;
    QQmlComponent component(m_engine, QUrl(QStringLiteral("qrc:/qt/qml/macdowsos files/main.qml")));
    QObject *object = component.createWithInitialProperties({{QStringLiteral("initialPath"), folder}});
    auto *window = qobject_cast<QQuickWindow *>(object);
    if (!window) {
        qWarning() << component.errors();
        delete object;
        return false;
    }
    QQmlEngine::setObjectOwnership(window, QQmlEngine::CppOwnership);
    window->QObject::setParent(this);
    // Offset additional windows within the screen's available work area.
    if (!m_windows.isEmpty()) {
        auto *previous = *m_windows.cbegin();
        const QRect area = previous->screen()->availableGeometry();
        window->setPosition(qBound(area.left(), previous->x() + 32, qMax(area.left(), area.right() - window->width() + 1)),
                            qBound(area.top(), previous->y() + 32, qMax(area.top(), area.bottom() - window->height() + 1)));
    }
    m_windows.insert(window);
    window->requestActivate();
    return true;
}

void WindowManager::releaseWindow(QQuickWindow *window)
{
    if (!m_windows.remove(window)) return;
    // Let Qt finish delivering the close event before destroying QML/native surfaces.
    window->deleteLater();
    if (m_windows.isEmpty())
        QTimer::singleShot(0, this, [this] { if (m_windows.isEmpty()) QCoreApplication::quit(); });
}
