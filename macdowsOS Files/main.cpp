//Qt
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <Windows.h>
int main(int argc, char *argv[]){
    MessageBoxA(NULL,
        "macdowsOS Files 目前仍在早期测试中 并不代表最终成品质量",
        "雾蓝回针MistBlueSt",
        MB_OK | MB_ICONINFORMATION);
    //别删 Qt自带
#if defined(Q_OS_WIN) && QT_VERSION_CHECK(5, 6, 0) <= QT_VERSION && QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#endif

    QGuiApplication app(argc, argv);
    // 开启无边框窗口的原生系统阴影
    QQuickWindow::setDefaultAlphaBuffer(true);

    QQmlApplicationEngine engine;
    engine.load(QUrl(QStringLiteral("qrc:/qt/qml/macdowsos files/main.qml")));
    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
