#pragma once

#include <QAbstractNativeEventFilter>
#include <QObject>
#include <QPointer>
#include <QQuickWindow>
#include <QQuickItem>
#include <QString>

struct IContextMenu2;
struct IContextMenu3;

// Windows composition and Shell menus stay on the GUI/COM apartment thread.
class NativeShell : public QObject, public QAbstractNativeEventFilter
{
    Q_OBJECT
    Q_PROPERTY(bool backdropAvailable READ backdropAvailable NOTIFY backdropAvailableChanged)
public:
    explicit NativeShell(QObject *parent = nullptr);
    ~NativeShell() override;
    bool backdropAvailable() const { return m_backdropAvailable; }
    Q_INVOKABLE void attachWindow(QQuickWindow *window);
    Q_INVOKABLE bool showContextMenu(const QString &path, QQuickItem *anchor,
                                     qreal x, qreal y, bool background = false);
    Q_INVOKABLE bool renameItem(const QString &path, const QString &newName);
    bool nativeEventFilter(const QByteArray &eventType, void *message, qintptr *result) override;
signals:
    void backdropAvailableChanged();
    void renameRequested(const QString &path, const QString &name);
    void operationFailed(const QString &message);
protected:
    bool eventFilter(QObject *watched, QEvent *event) override;
private:
    void applyBackdrop();
    void updateShadow();
    bool updateAcrylic(bool enabled);
    QPointer<QQuickWindow> m_window;
    QQuickWindow *m_shadowWindow = nullptr;
    QQuickWindow *m_acrylicWindow = nullptr;
    quintptr m_owner = 0;
    bool m_backdropAvailable = false;
    QSize m_cornerSize;
    int m_cornerRadius = -1;
    bool m_comInitialized = false;
    bool m_menuOpen = false;
    IContextMenu2 *m_menu2 = nullptr;
    IContextMenu3 *m_menu3 = nullptr;
};
