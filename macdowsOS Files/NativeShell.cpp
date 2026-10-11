#include "NativeShell.h"

#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QPlatformSurfaceEvent>
#include <QScopedValueRollback>
#include <QSettings>
#include <QQmlEngine>
#include <QTimer>
#include <QUrl>
#include <QAction>
#include <QApplication>
#include <QFontMetrics>
#include <QImage>
#include <QMenu>
#include <QPainter>
#include <QPainterPath>
#include <QRegion>
#include <QRegularExpression>
#include <QShowEvent>
#include <QStyleFactory>
#include <QStyle>
#include <QWidgetAction>
#include <QToolButton>

#include <Windows.h>
#include <dwmapi.h>
#include <shlobj.h>
#include <shobjidl.h>
#include <wrl/client.h>

#include <memory>
#include <functional>
#include <vector>

using Microsoft::WRL::ComPtr;

namespace {
struct PidlDeleter {
    using pointer = PIDLIST_ABSOLUTE;
    void operator()(pointer value) const { CoTaskMemFree(value); }
};
struct MenuDeleter { void operator()(HMENU__ *value) const { DestroyMenu(value); } };
using Pidl = std::unique_ptr<ITEMIDLIST, PidlDeleter>;
using Menu = std::unique_ptr<HMENU__, MenuDeleter>;

// The optional Windows compositor entry point supports Acrylic on Qt's
// frameless HWND without adding a native caption underneath translucent pixels.
// Resolve it at runtime; unsupported systems keep the opaque QML sidebar.
struct AccentPolicy { int state; int flags; DWORD color; int animation; };
struct CompositionAttributeData { int attribute; void *data; SIZE_T size; };
bool setAcrylic(HWND hwnd, bool enabled)
{
    using SetComposition = BOOL(WINAPI *)(HWND, CompositionAttributeData *);
    static const auto setComposition = reinterpret_cast<SetComposition>(
        GetProcAddress(GetModuleHandleW(L"user32.dll"), "SetWindowCompositionAttribute"));
    if (!setComposition) return false;
    // ACCENT_ENABLE_ACRYLICBLURBEHIND / ACCENT_DISABLED; color is AABBGGRR.
    AccentPolicy policy = {enabled ? 4 : 0, 2, 0x991c1c1c, 0};
    CompositionAttributeData data = {19, &policy, sizeof(policy)};
    return setComposition(hwnd, &data) != FALSE;
}

bool transparencyEnabled()
{
    QSettings settings(QStringLiteral("HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize"), QSettings::NativeFormat);
    return settings.value(QStringLiteral("EnableTransparency"), true).toBool();
}

// Region-clipped windows lose DWM shadows. A transparent, input-pass-through
// companion supplies the Windows shadow without painting a second outline.
class ShadowWindow final : public QQuickWindow {
public:
    ShadowWindow()
    {
        setFlags(Qt::Tool | Qt::FramelessWindowHint | Qt::WindowDoesNotAcceptFocus | Qt::WindowTransparentForInput);
        setColor(Qt::transparent);
    }
    void configure()
    {
        const HWND hwnd = reinterpret_cast<HWND>(winId());
        SetWindowLongPtrW(hwnd, GWL_STYLE, GetWindowLongPtrW(hwnd, GWL_STYLE) | WS_THICKFRAME);
        SetWindowLongPtrW(hwnd, GWL_EXSTYLE, GetWindowLongPtrW(hwnd, GWL_EXSTYLE) & ~WS_EX_LAYERED);
        const DWMNCRENDERINGPOLICY policy = DWMNCRP_ENABLED;
        DwmSetWindowAttribute(hwnd, DWMWA_NCRENDERING_POLICY, &policy, sizeof(policy));
        const COLORREF border = DWMWA_COLOR_NONE;
        DwmSetWindowAttribute(hwnd, DWMWA_BORDER_COLOR, &border, sizeof(border));
        const MARGINS margins = {-1, -1, -1, -1};
        DwmExtendFrameIntoClientArea(hwnd, &margins);
        const HRGN empty = CreateRectRgn(0, 0, 0, 0);
        DWM_BLURBEHIND alpha = {};
        alpha.dwFlags = DWM_BB_ENABLE | DWM_BB_BLURREGION;
        alpha.fEnable = TRUE;
        alpha.hRgnBlur = empty;
        DwmEnableBlurBehindWindow(hwnd, &alpha);
        DeleteObject(empty);
    }
protected:
    bool nativeEvent(const QByteArray &type, void *message, qintptr *result) override
    {
        if (static_cast<MSG *>(message)->message == WM_NCCALCSIZE) { *result = 0; return true; }
        return QQuickWindow::nativeEvent(type, message, result);
    }
};

class AcrylicWindow final : public QQuickWindow {
public:
    AcrylicWindow()
    {
        setFlags(Qt::Tool | Qt::FramelessWindowHint | Qt::WindowDoesNotAcceptFocus
                 | Qt::WindowTransparentForInput | Qt::NoDropShadowWindowHint);
        setColor(Qt::transparent);
    }
    bool configure()
    {
        const HWND hwnd = reinterpret_cast<HWND>(winId());
        const DWM_WINDOW_CORNER_PREFERENCE corners = DWMWCP_DONOTROUND;
        DwmSetWindowAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, &corners, sizeof(corners));
        const DWMNCRENDERINGPOLICY policy = DWMNCRP_DISABLED;
        DwmSetWindowAttribute(hwnd, DWMWA_NCRENDERING_POLICY, &policy, sizeof(policy));
        const MARGINS margins = {-1, -1, -1, -1};
        DwmExtendFrameIntoClientArea(hwnd, &margins);
        return setAcrylic(hwnd, true);
    }
};

class GlassShellMenu final : public QMenu {
public:
    explicit GlassShellMenu(QWidget *parent = nullptr) : QMenu(parent)
    {
        setObjectName(QStringLiteral("windowsShellMenu"));
        setWindowFlag(Qt::NoDropShadowWindowHint, false);
        setAttribute(Qt::WA_TranslucentBackground);
        static QStyle *style = [] {
            auto *result = QStyleFactory::create(QStringLiteral("Fusion"));
            result->setParent(qApp);
            return result;
        }();
        setStyle(style);
        QFont font = QApplication::font();
        font.setPixelSize(13);
        setFont(font);
        QPalette colors = palette();
        colors.setColor(QPalette::WindowText, QColor("#eeeeee"));
        colors.setColor(QPalette::Text, QColor("#eeeeee"));
        colors.setColor(QPalette::ButtonText, QColor("#eeeeee"));
        colors.setColor(QPalette::Highlight, QColor("#146de0"));
        colors.setColor(QPalette::HighlightedText, Qt::white);
        colors.setColor(QPalette::Disabled, QPalette::Text, QColor("#888888"));
        setPalette(colors);
        updateSurfaceStyle(transparencyEnabled());
    }
protected:
    void showEvent(QShowEvent *event) override
    {
        const HWND hwnd = reinterpret_cast<HWND>(winId());
        const bool acrylic = transparencyEnabled() && setAcrylic(hwnd, true);
        const BOOL dark = TRUE;
        DwmSetWindowAttribute(hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, &dark, sizeof(dark));
        const DWM_WINDOW_CORNER_PREFERENCE corners = DWMWCP_ROUND;
        m_nativeCorners = SUCCEEDED(DwmSetWindowAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, &corners, sizeof(corners)));
        const COLORREF border = RGB(80, 80, 80);
        DwmSetWindowAttribute(hwnd, DWMWA_BORDER_COLOR, &border, sizeof(border));
        const MARGINS margins = {-1, -1, -1, -1};
        DwmExtendFrameIntoClientArea(hwnd, &margins);
        updateSurfaceStyle(acrylic);
        QMenu::showEvent(event);
    }
private:
    bool m_nativeCorners = false;
    void updateSurfaceStyle(bool acrylic)
    {
        setStyleSheet(QStringLiteral(
            "QMenu { background: %1; %2 padding: 7px; }"
            "QMenu::item { min-width: 210px; padding: 6px 28px 6px 29px; border-radius: 6px; color: #eeeeee; }"
            "QMenu::item:selected { background: #bc146de0; color: white; }"
            "QMenu::item:disabled { color: #888888; }"
            "QMenu::separator { height: 1px; background: #4bffffff; margin: 6px 8px; }"
            "QMenu::icon { left: 7px; }"
            "QMenu::indicator { width: 14px; height: 14px; left: 7px; }"
            ).arg(acrylic ? QStringLiteral("rgba(43, 43, 43, 190)") : QStringLiteral("#303030"),
                  m_nativeCorners ? QStringLiteral("border: none; border-radius: 0;")
                                  : QStringLiteral("border: 1px solid #686868; border-radius: 12px;")));
    }
};

QImage menuBitmap(HBITMAP bitmap)
{
    if (reinterpret_cast<quintptr>(bitmap) <= 11 || bitmap == HBMMENU_CALLBACK) return {};
    BITMAP info = {};
    if (!GetObjectW(bitmap, sizeof(info), &info) || info.bmWidth <= 0 || info.bmHeight <= 0) return {};
    QImage result(info.bmWidth, info.bmHeight, QImage::Format_ARGB32);
    BITMAPINFO dib = {};
    dib.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    dib.bmiHeader.biWidth = info.bmWidth;
    dib.bmiHeader.biHeight = -info.bmHeight;
    dib.bmiHeader.biPlanes = 1;
    dib.bmiHeader.biBitCount = 32;
    dib.bmiHeader.biCompression = BI_RGB;
    const HDC dc = GetDC(nullptr);
    const bool copied = GetDIBits(dc, bitmap, 0, info.bmHeight, result.bits(), &dib, DIB_RGB_COLORS) != 0;
    ReleaseDC(nullptr, dc);
    if (!copied) return {};
    bool alpha = false;
    for (int y = 0; y < result.height(); ++y)
        for (int x = 0; x < result.width(); ++x) alpha |= qAlpha(result.pixel(x, y)) != 0;
    if (!alpha) result = result.convertToFormat(QImage::Format_RGB32);
    return result;
}

QString menuText(const std::wstring &value)
{
    QString text = QString::fromWCharArray(value.c_str());
    // Preserve mnemonic markers for Qt's keyboard handling, but omit the extra
    // Windows "(&X)" suffix from the visible label using Qt's ampersand syntax.
    const QRegularExpression suffix(QStringLiteral("\\(&([^&])\\)"));
    const auto match = suffix.match(text);
    if (match.hasMatch()) {
        const QString key = match.captured(1);
        text.remove(match.capturedStart(), match.capturedLength());
        const int index = text.indexOf(key, 0, Qt::CaseInsensitive);
        if (index >= 0) text.insert(index, '&');
        else text += QStringLiteral(" (&") + key + ')';
    }
    return text;
}

QString localPath(const QString &value)
{
    const QUrl url(value);
    return QDir::toNativeSeparators(url.isLocalFile() ? url.toLocalFile() : value);
}

ComPtr<IContextMenu> shellMenu(HWND owner, const QString &path, bool background)
{
    PIDLIST_ABSOLUTE rawPidl = nullptr;
    const auto native = path.toStdWString();
    if (FAILED(SHParseDisplayName(native.c_str(), nullptr, &rawPidl, 0, nullptr))) return {};
    Pidl pidl(rawPidl);
    ComPtr<IShellFolder> folder;
    ComPtr<IContextMenu> context;
    if (background) {
        if (SUCCEEDED(SHBindToObject(nullptr, pidl.get(), nullptr, IID_PPV_ARGS(&folder))))
            folder->CreateViewObject(owner, IID_PPV_ARGS(&context));
    } else {
        PCUITEMID_CHILD child = nullptr;
        if (SUCCEEDED(SHBindToParent(pidl.get(), IID_PPV_ARGS(&folder), &child)))
            folder->GetUIObjectOf(owner, 1, &child, IID_IContextMenu, nullptr,
                                  reinterpret_cast<void **>(context.GetAddressOf()));
    }
    return context;
}
}

NativeShell::NativeShell(QObject *parent) : QObject(parent)
{
    m_comInitialized = SUCCEEDED(OleInitialize(nullptr));
    QCoreApplication::instance()->installNativeEventFilter(this);
}

NativeShell::~NativeShell()
{
    delete m_shadowWindow;
    delete m_acrylicWindow;
    QCoreApplication::instance()->removeNativeEventFilter(this);
    if (m_comInitialized) OleUninitialize();
}

void NativeShell::attachWindow(QQuickWindow *window)
{
    if (m_window != window) {
        if (m_window) m_window->removeEventFilter(this);
        m_window = window;
        m_owner = 0;
        m_cornerSize = {};
        m_cornerRadius = -1;
        if (m_window) m_window->installEventFilter(this);
    }
    applyBackdrop();
}

void NativeShell::updateShadow()
{
    if (!m_window) return;
    const HWND owner = reinterpret_cast<HWND>(m_window->winId());
    if (!m_window->isVisible() || IsIconic(owner) || IsZoomed(owner)) {
        if (m_shadowWindow) m_shadowWindow->hide();
        return;
    }
    if (!m_shadowWindow) m_shadowWindow = new ShadowWindow;
    m_shadowWindow->setGeometry(m_window->geometry());
    if (!m_shadowWindow->isVisible()) m_shadowWindow->show();
    static_cast<ShadowWindow *>(m_shadowWindow)->configure();
    RECT bounds = {};
    GetWindowRect(owner, &bounds);
    SetWindowPos(reinterpret_cast<HWND>(m_shadowWindow->winId()), owner,
                 bounds.left, bounds.top, bounds.right - bounds.left, bounds.bottom - bounds.top,
                 SWP_NOACTIVATE | SWP_FRAMECHANGED);
}

bool NativeShell::updateAcrylic(bool enabled)
{
    if (!m_window || !enabled || !m_window->isVisible() || m_window->visibility() == QWindow::Minimized) {
        if (m_acrylicWindow) m_acrylicWindow->hide();
        return false;
    }
    if (!m_acrylicWindow) m_acrylicWindow = new AcrylicWindow;
    const int radius = m_window->visibility() == QWindow::Maximized ? 0 : m_window->property("windowCornerRadius").toInt();
    const int sidebarWidth = m_window->property("sidebarWidth").toInt();
    // Keep Acrylic clear of the rounded cutouts. The QML tint fades to opaque
    // at the top/bottom ends, so the material has no visible rectangular seam.
    const QRect area(m_window->x(), m_window->y() + radius, sidebarWidth, qMax(1, m_window->height() - 2 * radius));
    m_acrylicWindow->setGeometry(area);
    if (!m_acrylicWindow->isVisible()) m_acrylicWindow->show();
    const bool applied = static_cast<AcrylicWindow *>(m_acrylicWindow)->configure();
    const HWND owner = reinterpret_cast<HWND>(m_window->winId());
    const HWND acrylic = reinterpret_cast<HWND>(m_acrylicWindow->winId());
    SetWindowPos(acrylic, owner, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
    if (m_shadowWindow && m_shadowWindow->isVisible())
        SetWindowPos(reinterpret_cast<HWND>(m_shadowWindow->winId()), acrylic, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
    if (!applied) m_acrylicWindow->hide();
    return applied;
}

void NativeShell::applyBackdrop()
{
    if (!m_window) return;
    const HWND hwnd = reinterpret_cast<HWND>(m_window->winId());
    m_owner = reinterpret_cast<quintptr>(hwnd);
    const BOOL dark = TRUE;
    DwmSetWindowAttribute(hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, &dark, sizeof(dark));
    const bool systemTransparency = transparencyEnabled();
    // Keep native resize/snap behavior; only the companion renders DWM's
    // shadow. The content HWND paints no non-client frame at its corners.
    const LONG_PTR style = GetWindowLongPtrW(hwnd, GWL_STYLE);
    const LONG_PTR extendedStyle = GetWindowLongPtrW(hwnd, GWL_EXSTYLE);
    if (!(style & WS_THICKFRAME) || !(extendedStyle & WS_EX_LAYERED)) {
        SetWindowLongPtrW(hwnd, GWL_STYLE, style | WS_THICKFRAME);
        SetWindowLongPtrW(hwnd, GWL_EXSTYLE, extendedStyle | WS_EX_LAYERED);
        SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
                     SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
    }
    const DWMNCRENDERINGPOLICY policy = DWMNCRP_DISABLED;
    DwmSetWindowAttribute(hwnd, DWMWA_NCRENDERING_POLICY, &policy, sizeof(policy));
    // The content mask owns the large radius. Disable DWM's fixed small
    // corner and border so it cannot add a second silhouette.
    const DWM_WINDOW_CORNER_PREFERENCE corners = DWMWCP_DONOTROUND;
    DwmSetWindowAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, &corners, sizeof(corners));
    const COLORREF border = DWMWA_COLOR_NONE;
    DwmSetWindowAttribute(hwnd, DWMWA_BORDER_COLOR, &border, sizeof(border));
    const DWM_SYSTEMBACKDROP_TYPE backdrop = DWMSBT_NONE;
    DwmSetWindowAttribute(hwnd, DWMWA_SYSTEMBACKDROP_TYPE, &backdrop, sizeof(backdrop));
    setAcrylic(hwnd, false);
    const MARGINS margins = {};
    DwmExtendFrameIntoClientArea(hwnd, &margins);
    RECT bounds = {};
    GetWindowRect(hwnd, &bounds);
    const QSize cornerSize(bounds.right - bounds.left, bounds.bottom - bounds.top);
    const int logicalRadius = m_window->property("windowCornerRadius").toInt();
    const int radius = IsZoomed(hwnd) ? 0 : qRound(logicalRadius * m_window->devicePixelRatio());
    if (m_cornerSize != cornerSize || m_cornerRadius != radius) {
        QPainterPath shape;
        shape.addRoundedRect(QRectF(QPointF(), m_window->size()), radius ? logicalRadius : 0, radius ? logicalRadius : 0);
        m_window->setMask(radius ? QRegion(shape.toFillPolygon().toPolygon()) : QRegion());
        m_cornerSize = cornerSize;
        m_cornerRadius = radius;
    }
    updateShadow();
    const bool available = updateAcrylic(systemTransparency);
    if (m_backdropAvailable != available) {
        m_backdropAvailable = available;
        emit backdropAvailableChanged();
    }
}

bool NativeShell::eventFilter(QObject *watched, QEvent *event)
{
    if (watched == m_window && event->type() == QEvent::PlatformSurface) {
        const auto *surface = static_cast<QPlatformSurfaceEvent *>(event);
        if (surface->surfaceEventType() == QPlatformSurfaceEvent::SurfaceCreated)
            QTimer::singleShot(0, this, &NativeShell::applyBackdrop);
    } else if (watched == m_window && (event->type() == QEvent::Resize || event->type() == QEvent::Move || event->type() == QEvent::Show
                                     || event->type() == QEvent::Hide || event->type() == QEvent::WindowStateChange
                                     || event->type() == QEvent::DevicePixelRatioChange
                                     || event->type() == QEvent::WindowActivate || event->type() == QEvent::WindowDeactivate)) {
        // Restore the material after Qt updates its transparent window surface.
        QTimer::singleShot(0, this, &NativeShell::applyBackdrop);
    }
    return QObject::eventFilter(watched, event);
}

bool NativeShell::nativeEventFilter(const QByteArray &, void *message, qintptr *result)
{
    const auto *msg = static_cast<MSG *>(message);
    if (!m_window || !m_owner || msg->hwnd != reinterpret_cast<HWND>(m_owner)) return false;
    if (msg->message == WM_NCCALCSIZE) {
        if (msg->wParam && IsZoomed(msg->hwnd)) {
            auto *parameters = reinterpret_cast<NCCALCSIZE_PARAMS *>(msg->lParam);
            MONITORINFO monitor = {sizeof(MONITORINFO)};
            if (GetMonitorInfoW(MonitorFromWindow(msg->hwnd, MONITOR_DEFAULTTONEAREST), &monitor))
                parameters->rgrc[0] = monitor.rcWork;
        }
        *result = 0;
        return true;
    }
    if (msg->message == WM_DWMCOMPOSITIONCHANGED || msg->message == WM_SETTINGCHANGE) {
        QTimer::singleShot(0, this, &NativeShell::applyBackdrop);
        return false;
    }
    switch (msg->message) {
    case WM_INITMENUPOPUP:
    case WM_DRAWITEM:
    case WM_MEASUREITEM:
    case WM_MENUCHAR:
        if (m_menu3) {
            LRESULT menuResult = 0;
            if (SUCCEEDED(m_menu3->HandleMenuMsg2(msg->message, msg->wParam, msg->lParam, &menuResult))) {
                *result = menuResult;
                return true;
            }
        } else if (m_menu2 && SUCCEEDED(m_menu2->HandleMenuMsg(msg->message, msg->wParam, msg->lParam))) {
            *result = 0;
            return true;
        }
        break;
    }
    return false;
}

bool NativeShell::showContextMenu(const QString &value, QQuickItem *anchor, qreal x, qreal y, bool background)
{
    if (!m_comInitialized || !anchor || !anchor->window() || m_menuOpen) return false;
    QScopedValueRollback<bool> menuOpen(m_menuOpen, true);
    attachWindow(anchor->window());
    const QString path = localPath(value);
    if (!QFileInfo::exists(path) || (background && !QFileInfo(path).isDir())) return false;
    const HWND owner = reinterpret_cast<HWND>(m_window->winId());
    auto context = shellMenu(owner, path, background);
    Menu menu(CreatePopupMenu());
    if (!context || !menu) {
        emit operationFailed(tr("Unable to load the Windows context menu."));
        return false;
    }
    constexpr UINT firstCommand = 1;
    UINT flags = CMF_NORMAL | (background ? 0 : CMF_CANRENAME);
    if (GetKeyState(VK_SHIFT) < 0) flags |= CMF_EXTENDEDVERBS;
    if (FAILED(context->QueryContextMenu(menu.get(), 0, firstCommand, 0x7fff, flags))) {
        emit operationFailed(tr("Unable to load the Windows context menu."));
        return false;
    }
    ComPtr<IContextMenu3> menu3;
    ComPtr<IContextMenu2> menu2;
    context.As(&menu3);
    if (!menu3) context.As(&menu2);
    m_menu3 = menu3.Get();
    m_menu2 = menu2.Get();
    const QPointF point = anchor->mapToScene(QPointF(x, y));
    const qreal scale = m_window->devicePixelRatio();
    POINT screen = {qRound(point.x() * scale), qRound(point.y() * scale)};
    ClientToScreen(owner, &screen);
    auto handleMenuMessage = [&](UINT message, WPARAM wParam, LPARAM lParam) {
        LRESULT ignored = 0;
        if (menu3) return menu3->HandleMenuMsg2(message, wParam, lParam, &ignored);
        return menu2 ? menu2->HandleMenuMsg(message, wParam, lParam) : E_NOTIMPL;
    };
    GlassShellMenu popup;
    UINT selectedOwnerDrawCommand = 0;
    std::function<void(QMenu *, HMENU)> populate;
    populate = [&](QMenu *target, HMENU native) {
        target->clear();
        qDeleteAll(target->findChildren<QMenu *>(QString(), Qt::FindDirectChildrenOnly));
        const int count = GetMenuItemCount(native);
        for (int position = 0; position < count; ++position) {
            MENUITEMINFOW item = {};
            item.cbSize = sizeof(item);
            item.fMask = MIIM_FTYPE | MIIM_ID | MIIM_STATE | MIIM_STRING | MIIM_SUBMENU | MIIM_BITMAP | MIIM_DATA;
            GetMenuItemInfoW(native, position, TRUE, &item);
            std::wstring text(item.cch + 1, L'\0');
            item.dwTypeData = text.data();
            item.cch = static_cast<UINT>(text.size());
            if (!GetMenuItemInfoW(native, position, TRUE, &item)) continue;
            if (item.fType & MFT_SEPARATOR) { target->addSeparator(); continue; }
            QAction *action = nullptr;
            if (item.hSubMenu) {
                auto *submenu = new GlassShellMenu(target);
                submenu->setTitle(menuText(text));
                // Populate on opening: extensions such as 7-Zip and New can
                // generate their commands lazily in WM_INITMENUPOPUP.
                const HMENU child = item.hSubMenu;
                QObject::connect(submenu, &QMenu::aboutToShow, target, [&, submenu, child, position] {
                    handleMenuMessage(WM_INITMENUPOPUP, reinterpret_cast<WPARAM>(child), MAKELPARAM(position, FALSE));
                    populate(submenu, child);
                });
                action = target->addMenu(submenu);
            } else if (text[0] == L'\0' && (item.fType & MFT_OWNERDRAW)) {
                // Preserve owner-drawn extension entries that provide no label.
                MEASUREITEMSTRUCT measured = {ODT_MENU, 0, item.wID, 220, 24, item.dwItemData};
                handleMenuMessage(WM_MEASUREITEM, 0, reinterpret_cast<LPARAM>(&measured));
                const int width = qBound(24, static_cast<int>(measured.itemWidth), 600);
                const int height = qBound(18, static_cast<int>(measured.itemHeight), 80);
                BITMAPINFO dib = {};
                dib.bmiHeader = {sizeof(BITMAPINFOHEADER), width, -height, 1, 32, BI_RGB};
                void *pixels = nullptr;
                const HDC dc = CreateCompatibleDC(nullptr);
                const HBITMAP bitmap = CreateDIBSection(dc, &dib, DIB_RGB_COLORS, &pixels, nullptr, 0);
                if (bitmap && pixels) {
                    const HGDIOBJ old = SelectObject(dc, bitmap);
                    RECT bounds = {0, 0, width, height};
                    const HBRUSH brush = CreateSolidBrush(RGB(43, 43, 43));
                    FillRect(dc, &bounds, brush);
                    DeleteObject(brush);
                    DRAWITEMSTRUCT drawn = {ODT_MENU, 0, item.wID, ODA_DRAWENTIRE, 0,
                        reinterpret_cast<HWND>(native), dc, bounds, item.dwItemData};
                    handleMenuMessage(WM_DRAWITEM, 0, reinterpret_cast<LPARAM>(&drawn));
                    QImage rendered(static_cast<uchar *>(pixels), width, height, QImage::Format_RGB32);
                    auto *widgetAction = new QWidgetAction(target);
                    auto *button = new QToolButton;
                    button->setIcon(QPixmap::fromImage(rendered.copy()));
                    button->setIconSize(QSize(width, height));
                    button->setAutoRaise(true);
                    button->setStyleSheet(QStringLiteral("QToolButton { border: none; padding: 4px; border-radius: 6px; } QToolButton:hover { background: #146de0; }"));
                    widgetAction->setDefaultWidget(button);
                    QObject::connect(button, &QToolButton::clicked, &popup, [&, id = item.wID] {
                        selectedOwnerDrawCommand = id;
                        popup.close();
                    });
                    target->addAction(widgetAction);
                    action = widgetAction;
                    SelectObject(dc, old);
                }
                if (bitmap) DeleteObject(bitmap);
                DeleteDC(dc);
            }
            if (!action) action = target->addAction(menuText(text));
            action->setData(item.wID);
            action->setEnabled(!(item.fState & (MFS_DISABLED | MFS_GRAYED)));
            action->setCheckable(item.fState & MFS_CHECKED);
            action->setChecked(item.fState & MFS_CHECKED);
            const QImage icon = menuBitmap(item.hbmpItem);
            if (!icon.isNull()) action->setIcon(QPixmap::fromImage(icon));
            if (item.fState & MFS_DEFAULT) target->setDefaultAction(action);
        }
    };
    handleMenuMessage(WM_INITMENUPOPUP, reinterpret_cast<WPARAM>(menu.get()), 0);
    populate(&popup, menu.get());
    SetForegroundWindow(owner);
    // Qt handles popup placement, scrolling, keyboard navigation, and dismissal.
    // Only presentation changes; every command ID comes from this Shell menu.
    const QPoint globalPoint = m_window->mapToGlobal(point.toPoint());
    const QAction *selected = popup.exec(globalPoint);
    const UINT command = selected ? selected->data().toUInt() : selectedOwnerDrawCommand;
    m_menu3 = nullptr;
    m_menu2 = nullptr;
    PostMessageW(owner, WM_NULL, 0, 0);
    if (!command) return true; // Dismissal is a successful native-menu interaction.

    char verb[256] = {};
    context->GetCommandString(command - firstCommand, GCS_VERBA, nullptr, verb, sizeof(verb));
    if (!background && qstrcmp(verb, "rename") == 0) {
        // Rename needs a host-provided edit field; all other verbs stay in Shell.
        emit renameRequested(QUrl::fromLocalFile(path).toString(), QFileInfo(path).fileName());
        return true;
    }
    CMINVOKECOMMANDINFOEX invoke = {};
    invoke.cbSize = sizeof(invoke);
    invoke.fMask = CMIC_MASK_UNICODE | CMIC_MASK_PTINVOKE;
    if (GetKeyState(VK_CONTROL) < 0) invoke.fMask |= CMIC_MASK_CONTROL_DOWN;
    if (GetKeyState(VK_SHIFT) < 0) invoke.fMask |= CMIC_MASK_SHIFT_DOWN;
    invoke.hwnd = owner;
    invoke.lpVerb = MAKEINTRESOURCEA(command - firstCommand);
    invoke.lpVerbW = MAKEINTRESOURCEW(command - firstCommand);
    invoke.nShow = SW_SHOWNORMAL;
    invoke.ptInvoke = screen;
    const auto directory = (background ? path : QFileInfo(path).absolutePath()).toStdWString();
    invoke.lpDirectoryW = directory.c_str();
    const HRESULT invoked = context->InvokeCommand(reinterpret_cast<LPCMINVOKECOMMANDINFO>(&invoke));
    if (FAILED(invoked)) emit operationFailed(tr("Windows could not complete this action."));
    return SUCCEEDED(invoked);
}

bool NativeShell::renameItem(const QString &value, const QString &newName)
{
    if (!m_comInitialized || !m_window || newName.isEmpty() || newName == "." || newName == ".."
        || newName.contains('/') || newName.contains('\\')) return false;
    const auto path = localPath(value).toStdWString();
    const auto name = newName.toStdWString();
    ComPtr<IShellItem> item;
    ComPtr<IFileOperation> operation;
    if (FAILED(SHCreateItemFromParsingName(path.c_str(), nullptr, IID_PPV_ARGS(&item)))
        || FAILED(CoCreateInstance(CLSID_FileOperation, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&operation)))) return false;
    operation->SetOwnerWindow(reinterpret_cast<HWND>(m_window->winId()));
    operation->SetOperationFlags(FOF_ALLOWUNDO | FOFX_ADDUNDORECORD);
    if (FAILED(operation->RenameItem(item.Get(), name.c_str(), nullptr))) return false;
    const HRESULT completed = operation->PerformOperations();
    BOOL aborted = FALSE;
    operation->GetAnyOperationsAborted(&aborted);
    return SUCCEEDED(completed) && !aborted;
}

// Each browser window owns its compositor surfaces and Shell operation signals.
static const int nativeShellRegistration = qmlRegisterType<NativeShell>(
    "macdowsOS.Locations", 1, 0, "NativeShellBackend");
