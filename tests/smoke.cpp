#include "FileLocations.h"
#include "FileIconProvider.h"
#include "NativeShell.h"
#include "WindowManager.h"
#include "WindowsIntegration.h"

#include <QApplication>
#include <QDir>
#include <QFile>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickItem>
#include <QSettings>
#include <QTemporaryDir>
#include <QTest>
#include <QUuid>
#include <Windows.h>
#include <aclapi.h>
#include <cstdio>

#define CHECK(condition) do { if (!(condition)) qFatal("FAIL at line %d: %s", __LINE__, #condition); } while (false)

static void registryTests(const QString &temporary)
{
    const QString root = QStringLiteral("Software\\macdowsOS\\Tests\\") + QUuid::createUuid().toString(QUuid::WithoutBraces);
    const QString classes = root + QStringLiteral("\\Classes");
    QSettings registry(QStringLiteral("HKEY_CURRENT_USER\\") + classes, QSettings::NativeFormat);
    WindowsIntegration integration(classes, temporary + QStringLiteral("/backup.ini"));
    CHECK(!integration.enabled());
    CHECK(!integration.canRestore());
    CHECK(integration.setEnabled(true));
    CHECK(integration.enabled());
    CHECK(integration.canRestore());
    CHECK(integration.setEnabled(true)); // Repeated activation cannot overwrite the backup.
    registry.sync();
    const QString command = registry.value(QStringLiteral("Drive/shell/macdowsOSFiles/command/Default")).toString();
    CHECK(command.contains(QStringLiteral("--open \"%1/\"")));

    // Round-trip the registered drive-root command through Windows argv parsing.
    QString rootCommand = command;
    rootCommand.replace(QStringLiteral("%1"), QStringLiteral("C:\\"));
    int count = 0;
    LPWSTR *args = CommandLineToArgvW(rootCommand.toStdWString().c_str(), &count);
    CHECK(args && count == 3);
    CHECK(QDir::cleanPath(QDir::fromNativeSeparators(QString::fromWCharArray(args[2]))) == QStringLiteral("C:/"));
    LocalFree(args);
    CHECK(integration.setEnabled(false));
    CHECK(!integration.canRestore());
    registry.sync();
    CHECK(!registry.contains(QStringLiteral("Directory/shell/Default")));
    CHECK(!registry.contains(QStringLiteral("Drive/shell/Default")));

    registry.setValue(QStringLiteral("Directory/shell/Default"), QStringLiteral("previousManager"));
    registry.setValue(QStringLiteral("Drive/shell/Default"), QStringLiteral("none"));
    registry.sync();
    CHECK(integration.setEnabled(true));
    CHECK(integration.setEnabled(false));
    registry.sync();
    CHECK(registry.value(QStringLiteral("Directory/shell/Default")) == QStringLiteral("previousManager"));
    CHECK(registry.value(QStringLiteral("Drive/shell/Default")) == QStringLiteral("none"));

    CHECK(integration.setEnabled(true));
    // Recovery also works after restarting/moving the app; state lives on disk.
    WindowsIntegration restarted(classes, temporary + QStringLiteral("/backup.ini"));
    CHECK(restarted.canRestore());
    registry.setValue(QStringLiteral("Directory/shell/Default"), QStringLiteral("newerManager"));
    registry.sync();
    CHECK(restarted.setEnabled(false));
    registry.sync();
    CHECK(registry.value(QStringLiteral("Directory/shell/Default")) == QStringLiteral("newerManager"));

    // Never overwrite a foreign key even if it has no default menu label.
    registry.setValue(QStringLiteral("Directory/shell/macdowsOSFiles/command/Default"), QStringLiteral("foreign.exe"));
    registry.sync();
    CHECK(!integration.setEnabled(true));
    CHECK(!integration.canRestore());
    CHECK(registry.value(QStringLiteral("Directory/shell/macdowsOSFiles/command/Default")) == QStringLiteral("foreign.exe"));
    registry.remove(QStringLiteral("Directory/shell/macdowsOSFiles"));
    registry.sync();

    // Force failure on the second class, after Directory was changed, to
    // verify that a partial install restores both defaults and removes its verb.
    HKEY driveKey = nullptr;
    CHECK(RegOpenKeyExW(HKEY_CURRENT_USER, (classes + QStringLiteral("\\Drive\\shell")).toStdWString().c_str(),
                        0, READ_CONTROL | WRITE_DAC, &driveKey) == ERROR_SUCCESS);
    DWORD securitySize = 0;
    CHECK(RegGetKeySecurity(driveKey, DACL_SECURITY_INFORMATION, nullptr, &securitySize) == ERROR_INSUFFICIENT_BUFFER);
    QByteArray security(securitySize, 0);
    auto *originalSecurity = reinterpret_cast<PSECURITY_DESCRIPTOR>(security.data());
    CHECK(RegGetKeySecurity(driveKey, DACL_SECURITY_INFORMATION, originalSecurity, &securitySize) == ERROR_SUCCESS);
    BOOL present = FALSE, defaulted = FALSE;
    PACL originalAcl = nullptr;
    CHECK(GetSecurityDescriptorDacl(originalSecurity, &present, &originalAcl, &defaulted));
    BYTE everyone[SECURITY_MAX_SID_SIZE];
    DWORD sidSize = sizeof(everyone);
    CHECK(CreateWellKnownSid(WinWorldSid, nullptr, everyone, &sidSize));
    EXPLICIT_ACCESSW denied = {};
    denied.grfAccessPermissions = KEY_CREATE_SUB_KEY;
    denied.grfAccessMode = DENY_ACCESS;
    denied.Trustee.TrusteeForm = TRUSTEE_IS_SID;
    denied.Trustee.ptstrName = reinterpret_cast<LPWSTR>(everyone);
    PACL testAcl = nullptr;
    CHECK(SetEntriesInAclW(1, &denied, originalAcl, &testAcl) == ERROR_SUCCESS);
    SECURITY_DESCRIPTOR testSecurity;
    CHECK(InitializeSecurityDescriptor(&testSecurity, SECURITY_DESCRIPTOR_REVISION));
    CHECK(SetSecurityDescriptorDacl(&testSecurity, TRUE, testAcl, FALSE));
    CHECK(RegSetKeySecurity(driveKey, DACL_SECURITY_INFORMATION, &testSecurity) == ERROR_SUCCESS);
    const bool installed = integration.setEnabled(true);
    CHECK(RegSetKeySecurity(driveKey, DACL_SECURITY_INFORMATION, originalSecurity) == ERROR_SUCCESS);
    LocalFree(testAcl);
    RegCloseKey(driveKey);
    CHECK(!installed);
    CHECK(!integration.canRestore());
    registry.sync();
    CHECK(registry.value(QStringLiteral("Directory/shell/Default")) == QStringLiteral("newerManager"));
    CHECK(registry.value(QStringLiteral("Drive/shell/Default")) == QStringLiteral("none"));
    CHECK(!registry.contains(QStringLiteral("Directory/shell/macdowsOSFiles/command/Default")));
    CHECK(RegDeleteTreeW(HKEY_CURRENT_USER, root.toStdWString().c_str()) == ERROR_SUCCESS);
    std::puts("PASS: registry install, restored values, restart recovery, foreign settings, drive quoting, partial failure rollback");
}

static QList<QQuickWindow *> browserWindows(WindowManager &manager)
{
    return manager.findChildren<QQuickWindow *>(QStringLiteral("finderWindow"), Qt::FindDirectChildrenOnly);
}

static void navigate(QQuickWindow *window, const QString &path)
{
    QObject *input = window->findChild<QObject *>(QStringLiteral("pathInput"));
    CHECK(input);
    input->setProperty("text", path);
    CHECK(QMetaObject::invokeMethod(input, "accepted"));
    QTest::qWait(100);
}

int main(int argc, char **argv)
{
    qputenv("QT_QUICK_CONTROLS_STYLE", "Basic");
    QApplication app(argc, argv);
    app.setQuitOnLastWindowClosed(false);
    QQuickWindow::setDefaultAlphaBuffer(true);
    QTemporaryDir temporary;
    CHECK(temporary.isValid());
    registryTests(temporary.path());

    const QString firstFolder = temporary.path() + QStringLiteral("/中文 空格 # %");
    const QString secondFolder = temporary.path() + QStringLiteral("/second");
    CHECK(QDir().mkpath(firstFolder));
    CHECK(QDir().mkpath(secondFolder));
    QFile sample(secondFolder + QStringLiteral("/example.txt"));
    CHECK(sample.open(QIODevice::WriteOnly));
    sample.write("Example file for multi-window smoke test\n");
    sample.close();
    FileLocations locations;
    CHECK(locations.nativePath(locations.normalizeFolder(firstFolder)) == QDir::toNativeSeparators(firstFolder));
    CHECK(locations.nativePath(QStringLiteral("file://server/share/folder")) == QStringLiteral("\\\\server\\share\\folder"));
    CHECK(locations.normalizeFolder(QStringLiteral("https://example.com")).isEmpty());

    QQmlApplicationEngine engine;
    WindowsIntegration integration;
    WindowManager manager(&engine);
    engine.rootContext()->setContextProperty(QStringLiteral("WindowManager"), &manager);
    engine.rootContext()->setContextProperty(QStringLiteral("WindowsIntegration"), &integration);
    engine.addImageProvider(QStringLiteral("file-icons"), new FileIconProvider);
    QStringList warnings;
    QObject::connect(&engine, &QQmlEngine::warnings, [&warnings](const QList<QQmlError> &errors) {
        for (const auto &error : errors) warnings.append(error.toString());
    });
    CHECK(manager.openWindow(firstFolder));
    QTest::qWait(400);
    auto *first = browserWindows(manager).first();
    auto *input = first->findChild<QObject *>(QStringLiteral("pathInput"));
    CHECK(input->property("text") == QDir::toNativeSeparators(firstFolder));
    CHECK(!input->property("text").toString().startsWith(QStringLiteral("file:")));

    // Exercise the actual plus button signal and its QML connection.
    auto *plus = first->findChild<QObject *>(QStringLiteral("newWindowButton"));
    CHECK(plus && QMetaObject::invokeMethod(plus, "clicked"));
    QTest::qWait(300);
    CHECK(browserWindows(manager).size() == 2);
    auto *second = browserWindows(manager).last();
    CHECK(first->findChild<NativeShell *>() != second->findChild<NativeShell *>());
    CHECK(second->findChild<QObject *>(QStringLiteral("pathInput"))->property("text") == input->property("text"));
    first->findChild<QObject *>(QStringLiteral("searchInput"))->setProperty("text", QStringLiteral("独立搜索"));
    CHECK(second->findChild<QObject *>(QStringLiteral("searchInput"))->property("text").toString().isEmpty());
    navigate(second, secondFolder);
    CHECK(second->findChild<QObject *>(QStringLiteral("pathInput"))->property("text") == QDir::toNativeSeparators(secondFolder));
    CHECK(input->property("text") == QDir::toNativeSeparators(firstFolder));
    auto *secondFiles = second->findChild<QObject *>(QStringLiteral("fileBrowser"));
    CHECK(QMetaObject::invokeMethod(secondFiles, "select", Q_ARG(QVariant, QVariant(0))));
    CHECK(!secondFiles->property("selectedPath").toString().isEmpty());
    CHECK(first->findChild<QObject *>(QStringLiteral("fileBrowser"))->property("selectedPath").toString().isEmpty());
    navigate(second, temporary.path() + QStringLiteral("/missing"));
    CHECK(!second->findChild<QObject *>(QStringLiteral("pathInput"))->property("pathValid").toBool());
    QTest::keyClick(second, Qt::Key_Escape);
    navigate(second, firstFolder);
    navigate(second, QUrl::fromLocalFile(secondFolder).toString());

    const QString screenshot = qEnvironmentVariable("MACDOWS_TEST_SCREENSHOT");
    if (!screenshot.isEmpty()) CHECK(second->grabWindow().save(screenshot));
    first->close();
    QCoreApplication::sendPostedEvents(nullptr, QEvent::DeferredDelete);
    QTest::qWait(100);
    CHECK(browserWindows(manager).size() == 1);
    navigate(second, firstFolder);
    CHECK(second->findChild<QObject *>(QStringLiteral("pathInput"))->property("text") == QDir::toNativeSeparators(firstFolder));
    CHECK(!manager.openWindow(temporary.path() + QStringLiteral("/missing")));
    second->requestActivate();
    QTest::qWait(100);
    QTest::keyClick(second, Qt::Key_N, Qt::ControlModifier);
    QTest::qWait(200);
    CHECK(browserWindows(manager).size() == 2);
    auto *third = browserWindows(manager).last();
    third->requestActivate();
    QTest::qWait(100);
    QTest::keyClick(third, Qt::Key_W, Qt::ControlModifier);
    QCoreApplication::sendPostedEvents(nullptr, QEvent::DeferredDelete);
    CHECK(browserWindows(manager).size() == 1);
    second->close();
    QCoreApplication::sendPostedEvents(nullptr, QEvent::DeferredDelete);
    CHECK(browserWindows(manager).isEmpty());
    CHECK(warnings.isEmpty());
    std::puts("PASS: native/UNC paths, plus button, independent windows, invalid paths, URL input, close cleanup, QML runtime");
    return 0;
}
