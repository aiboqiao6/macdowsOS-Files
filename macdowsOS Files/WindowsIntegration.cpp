#include "WindowsIntegration.h"

#include <QCoreApplication>
#include <QDir>
#include <QSettings>
#include <QStandardPaths>
#include <Windows.h>
#include <shlobj.h>

namespace {
const QString verb = QStringLiteral("macdowsOSFiles");
const QStringList classes = {QStringLiteral("Directory"), QStringLiteral("Drive")};

struct Value {
    bool exists = false;
    DWORD type = REG_SZ;
    QByteArray data;
};

LSTATUS handlerAvailable(const QString &path)
{
    HKEY key = nullptr;
    const LSTATUS status = RegOpenKeyExW(HKEY_CURRENT_USER, path.toStdWString().c_str(), 0, KEY_QUERY_VALUE, &key);
    if (key) RegCloseKey(key);
    return status == ERROR_FILE_NOT_FOUND ? ERROR_SUCCESS : (status == ERROR_SUCCESS ? ERROR_ALREADY_EXISTS : status);
}

LSTATUS readDefault(const QString &path, Value &value)
{
    HKEY key = nullptr;
    LSTATUS status = RegOpenKeyExW(HKEY_CURRENT_USER, path.toStdWString().c_str(), 0, KEY_QUERY_VALUE, &key);
    if (status == ERROR_FILE_NOT_FOUND) return ERROR_SUCCESS;
    if (status != ERROR_SUCCESS) return status;
    DWORD size = 0;
    status = RegQueryValueExW(key, nullptr, nullptr, &value.type, nullptr, &size);
    if (status == ERROR_SUCCESS) {
        value.data.resize(size);
        status = RegQueryValueExW(key, nullptr, nullptr, &value.type,
                                 reinterpret_cast<BYTE *>(value.data.data()), &size);
        value.exists = status == ERROR_SUCCESS;
        value.data.resize(size);
    }
    RegCloseKey(key);
    return status == ERROR_FILE_NOT_FOUND ? ERROR_SUCCESS : status;
}

QString asString(const Value &value)
{
    if (!value.exists || value.type != REG_SZ || value.data.size() % sizeof(wchar_t)) return {};
    QString result = QString::fromWCharArray(reinterpret_cast<const wchar_t *>(value.data.constData()),
                                           value.data.size() / sizeof(wchar_t));
    while (result.endsWith(QChar(0))) result.chop(1);
    return result;
}

LSTATUS writeDefault(const QString &path, const Value &value)
{
    HKEY key = nullptr;
    LSTATUS status = value.exists
        ? RegCreateKeyExW(HKEY_CURRENT_USER, path.toStdWString().c_str(), 0, nullptr, 0, KEY_SET_VALUE, nullptr, &key, nullptr)
        : RegOpenKeyExW(HKEY_CURRENT_USER, path.toStdWString().c_str(), 0, KEY_SET_VALUE, &key);
    if (!value.exists && status == ERROR_FILE_NOT_FOUND) return ERROR_SUCCESS;
    if (status != ERROR_SUCCESS) return status;
    status = value.exists
        ? RegSetValueExW(key, nullptr, 0, value.type, reinterpret_cast<const BYTE *>(value.data.constData()), value.data.size())
        : RegDeleteValueW(key, nullptr);
    RegCloseKey(key);
    return status == ERROR_FILE_NOT_FOUND ? ERROR_SUCCESS : status;
}

LSTATUS writeString(const QString &path, const QString &text)
{
    const auto native = text.toStdWString();
    return writeDefault(path, {true, REG_SZ, QByteArray(reinterpret_cast<const char *>(native.c_str()),
                                                       (native.size() + 1) * sizeof(wchar_t))});
}

QString command()
{
    // A trailing slash keeps a drive root's final backslash away from the quote
    // in Windows argv parsing; QDir normalizes the appended slash on startup.
    return QStringLiteral("\"%1\" --open \"%2/\"")
        .arg(QDir::toNativeSeparators(QCoreApplication::applicationFilePath()), QStringLiteral("%1"));
}
}

WindowsIntegration::WindowsIntegration(QObject *parent)
    : WindowsIntegration(QStringLiteral("Software\\Classes"),
          QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation) + QStringLiteral("/windows-integration.ini"), parent) {}

WindowsIntegration::WindowsIntegration(const QString &classesRoot, const QString &backupFile, QObject *parent)
    : QObject(parent), m_classesRoot(classesRoot), m_backupFile(backupFile) {}

bool WindowsIntegration::enabled() const
{
    for (const QString &name : classes) {
        const QString shell = m_classesRoot + QLatin1Char('\\') + name + QStringLiteral("\\shell");
        Value current, handler;
        if (readDefault(shell, current) != ERROR_SUCCESS || asString(current) != verb
            || readDefault(shell + QLatin1Char('\\') + verb + QStringLiteral("\\command"), handler) != ERROR_SUCCESS
            || asString(handler) != command()) return false;
    }
    return true;
}

bool WindowsIntegration::canRestore() const
{
    QSettings backup(m_backupFile, QSettings::IniFormat);
    return backup.value(QStringLiteral("active"), false).toBool();
}

bool WindowsIntegration::setEnabled(bool enable)
{
    m_lastError.clear();
    const bool ok = enable ? install() : restore();
    if (ok) SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, nullptr, nullptr);
    emit stateChanged();
    return ok;
}

bool WindowsIntegration::install()
{
    if (enabled()) return true;
    QSettings backup(m_backupFile, QSettings::IniFormat);
    if (canRestore()) {
        m_lastError = tr("请先恢复上次的文件管理器设置，再重新开启接管。");
        return false;
    }
    // Persist all previous values before touching any association.
    for (const QString &name : classes) {
        const QString shell = m_classesRoot + QLatin1Char('\\') + name + QStringLiteral("\\shell");
        Value previous;
        if (readDefault(shell, previous) != ERROR_SUCCESS
            || handlerAvailable(shell + QLatin1Char('\\') + verb) != ERROR_SUCCESS
            || asString(previous) == verb) {
            m_lastError = tr("无法读取原有设置，或接管菜单已被占用。未更改默认文件管理器。");
            return false;
        }
        backup.setValue(name + QStringLiteral("/exists"), previous.exists);
        backup.setValue(name + QStringLiteral("/type"), static_cast<uint>(previous.type));
        backup.setValue(name + QStringLiteral("/data"), previous.data);
    }
    backup.setValue(QStringLiteral("command"), command());
    backup.setValue(QStringLiteral("active"), true);
    backup.sync();
    if (backup.status() != QSettings::NoError) {
        m_lastError = tr("无法保存原有设置，未开启接管。");
        return false;
    }
    for (const QString &name : classes) {
        const QString shell = m_classesRoot + QLatin1Char('\\') + name + QStringLiteral("\\shell");
        const QString handler = shell + QLatin1Char('\\') + verb;
        const auto status = writeString(handler, tr("使用 macdowsOS Files 打开"));
        if (status != ERROR_SUCCESS
            || writeString(handler + QStringLiteral("\\command"), command()) != ERROR_SUCCESS
            || writeString(shell, verb) != ERROR_SUCCESS) {
            const bool rolledBack = restore();
            m_lastError = rolledBack ? tr("Windows 拒绝修改默认打开方式，已恢复原有设置。")
                                    : tr("接管未完成，请点击恢复默认文件管理器重试。");
            return false;
        }
    }
    return true;
}

bool WindowsIntegration::restore()
{
    QSettings backup(m_backupFile, QSettings::IniFormat);
    if (!canRestore()) return true;
    const QString savedCommand = backup.value(QStringLiteral("command")).toString();
    for (const QString &name : classes) {
        const QString shell = m_classesRoot + QLatin1Char('\\') + name + QStringLiteral("\\shell");
        const QString handler = shell + QLatin1Char('\\') + verb;
        Value current, currentCommand;
        if (readDefault(shell, current) != ERROR_SUCCESS
            || readDefault(handler + QStringLiteral("\\command"), currentCommand) != ERROR_SUCCESS) {
            m_lastError = tr("无法读取 Windows 打开方式，请稍后重试恢复。");
            return false;
        }
        // Another application's newer default must survive our restoration.
        if (asString(current) == verb) {
            const Value previous = {backup.value(name + QStringLiteral("/exists")).toBool(),
                backup.value(name + QStringLiteral("/type")).toUInt(),
                backup.value(name + QStringLiteral("/data")).toByteArray()};
            if (writeDefault(shell, previous) != ERROR_SUCCESS) {
                m_lastError = tr("无法恢复 Windows 打开方式，请重试。");
                return false;
            }
        }
        if (!currentCommand.exists || asString(currentCommand) == savedCommand) {
            const LSTATUS status = RegDeleteTreeW(HKEY_CURRENT_USER, handler.toStdWString().c_str());
            if (status != ERROR_SUCCESS && status != ERROR_FILE_NOT_FOUND) {
                m_lastError = tr("无法移除接管菜单，请重试恢复。");
                return false;
            }
        }
    }
    backup.clear();
    backup.sync();
    if (backup.status() != QSettings::NoError) {
        m_lastError = tr("原有打开方式已恢复，但无法清理备份，请重试。");
        return false;
    }
    return true;
}
