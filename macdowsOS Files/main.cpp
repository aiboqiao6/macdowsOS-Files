#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QFont>
#include <QCommandLineParser>
#include <QMessageBox>
#include <QQmlContext>
#include "WindowManager.h"
#include "WindowsIntegration.h"

#include "FileIconProvider.h"

// Application bootstrap:
// 1. Configure Qt Quick Controls and the transparent window surface.
// 2. Register the Windows file-icon image provider.
// 3. Load the QML root component from the compiled resource file.
int main(int argc, char *argv[])
{
    qputenv("QT_QUICK_CONTROLS_STYLE", "Basic");
    QApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("macdowsOS Files"));
    app.setOrganizationName(QStringLiteral("macdowsOS"));
    app.setQuitOnLastWindowClosed(false);
    app.setFont(QFont(QStringLiteral("Microsoft YaHei UI"), 10));
    QQuickWindow::setDefaultAlphaBuffer(true);

    QQmlApplicationEngine engine;
    WindowsIntegration integration;
    WindowManager windows(&engine);
    engine.rootContext()->setContextProperty(QStringLiteral("WindowManager"), &windows);
    engine.rootContext()->setContextProperty(QStringLiteral("WindowsIntegration"), &integration);
    // QML requests native file icons with image://file-icons/<encoded-path>.
    engine.addImageProvider(QStringLiteral("file-icons"), new FileIconProvider);
    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("macdowsOS Files"));
    parser.addHelpOption();
    parser.addOption({QStringLiteral("open"), QStringLiteral("Open a filesystem folder in a new window."), QStringLiteral("folder")});
    parser.addPositionalArgument(QStringLiteral("folder"), QStringLiteral("Folder to open."), QStringLiteral("[folder]"));
    parser.process(app);
    QStringList folders = parser.positionalArguments();
    if (parser.isSet(QStringLiteral("open"))) folders.prepend(parser.value(QStringLiteral("open")));
    if (folders.isEmpty()) folders.append(QString());
    bool opened = false;
    for (const QString &folder : folders) {
        if (windows.openWindow(folder)) opened = true;
        else QMessageBox::warning(nullptr, QStringLiteral("macdowsOS Files"),
            QStringLiteral("无法打开文件夹：%1").arg(folder));
    }
    if (!opened) return 1;
    return app.exec();
}
