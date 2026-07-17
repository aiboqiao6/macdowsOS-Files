#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickWindow>

#include <Windows.h>

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
        L"macdowsOS Files 版本 Developer Beta 0.1.1",
        L"雾蓝回针 MistBlueSt",
        MB_OK | MB_ICONINFORMATION);

    QQmlApplicationEngine engine;
    engine.load(QUrl(QStringLiteral("qrc:/qt/qml/macdowsos files/main.qml")));
    if (engine.rootObjects().isEmpty()) return -1;
    return app.exec();
}
