#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QFont>

#include "FileIconProvider.h"

// Application bootstrap:
// 1. Configure Qt Quick Controls and the transparent window surface.
// 2. Register the Windows file-icon image provider.
// 3. Load the QML root component from the compiled resource file.
int main(int argc, char *argv[])
{
    qputenv("QT_QUICK_CONTROLS_STYLE", "Basic");
    QApplication app(argc, argv);
    app.setFont(QFont(QStringLiteral("Microsoft YaHei UI"), 10));
    QQuickWindow::setDefaultAlphaBuffer(true);

    QQmlApplicationEngine engine;
    // QML requests native file icons with image://file-icons/<encoded-path>.
    engine.addImageProvider(QStringLiteral("file-icons"), new FileIconProvider);
    engine.load(QUrl(QStringLiteral("qrc:/qt/qml/macdowsos files/main.qml")));
    if (engine.rootObjects().isEmpty()) return -1;
    return app.exec();
}
