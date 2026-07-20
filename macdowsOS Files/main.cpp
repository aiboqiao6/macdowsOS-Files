#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickWindow>

#include <Windows.h>

#include "FileIconProvider.h"

// Application bootstrap:
// 1. Configure Qt Quick Controls and the transparent window surface.
// 2. Register the Windows file-icon image provider.
// 3. Load the QML root component from the compiled resource file.
int main(int argc, char *argv[])
{
    qputenv("QT_QUICK_CONTROLS_STYLE", "Basic");
    QGuiApplication app(argc, argv);
    QQuickWindow::setDefaultAlphaBuffer(true);

    MessageBoxW(nullptr,
        L"macdowsOS Files 目前仍在早期测试中，并不代表最终成品质量。",
        L"雾蓝回针 MistBlueSt",
        MB_OK | MB_ICONINFORMATION);
    MessageBoxW(nullptr,
        L"macdowsOS Files 版本 Developer Beta 0.12",
        L"雾蓝回针 MistBlueSt",
        MB_OK | MB_ICONINFORMATION);

    QQmlApplicationEngine engine;
    // QML requests native file icons with image://file-icons/<encoded-path>.
    engine.addImageProvider(QStringLiteral("file-icons"), new FileIconProvider);
    engine.load(QUrl(QStringLiteral("qrc:/qt/qml/macdowsos files/main.qml")));
    if (engine.rootObjects().isEmpty()) return -1;
    return app.exec();
}
