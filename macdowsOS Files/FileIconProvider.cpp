#include "FileIconProvider.h"

#include <QFileInfo>
#include <QDir>
#include <QImage>
#include <QPixmap>
#include <QUrl>

#include <Windows.h>
#include <shellapi.h>
#include <cstring>
#include <string>

namespace {

QPixmap pixmapFromHicon(HICON icon, int size)
{
    if (!icon)
        return {};

    BITMAPINFO bitmapInfo{};
    bitmapInfo.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bitmapInfo.bmiHeader.biWidth = size;
    bitmapInfo.bmiHeader.biHeight = -size;
    bitmapInfo.bmiHeader.biPlanes = 1;
    bitmapInfo.bmiHeader.biBitCount = 32;
    bitmapInfo.bmiHeader.biCompression = BI_RGB;

    HDC screen = GetDC(nullptr);
    HDC device = CreateCompatibleDC(screen);
    void *bits = nullptr;
    HBITMAP bitmap = CreateDIBSection(screen, &bitmapInfo, DIB_RGB_COLORS, &bits, nullptr, 0);
    if (!bitmap || !device || !bits) {
        if (bitmap) DeleteObject(bitmap);
        if (device) DeleteDC(device);
        if (screen) ReleaseDC(nullptr, screen);
        return {};
    }

    HGDIOBJ previous = SelectObject(device, bitmap);
    std::memset(bits, 0, static_cast<size_t>(size) * static_cast<size_t>(size) * 4);
    DrawIconEx(device, 0, 0, icon, size, size, 0, nullptr, DI_NORMAL);
    QImage image(static_cast<uchar *>(bits), size, size, QImage::Format_ARGB32_Premultiplied);
    QPixmap result = QPixmap::fromImage(image.copy());

    SelectObject(device, previous);
    DeleteObject(bitmap);
    DeleteDC(device);
    ReleaseDC(nullptr, screen);
    return result;
}

}

FileIconProvider::FileIconProvider()
    : QQuickImageProvider(QQuickImageProvider::Pixmap)
{
}

QPixmap FileIconProvider::requestPixmap(const QString &id, QSize *size, const QSize &requestedSize)
{
    // Image URLs carry an encoded file URL. Decode and normalize it before
    // handing the path to the Windows Shell icon associations.
    const QString value = QUrl::fromPercentEncoding(id.toUtf8());
    const QUrl url(value);
    const QString path = url.isLocalFile() ? url.toLocalFile() : QDir::fromNativeSeparators(value);
    const QSize targetSize = requestedSize.isValid() ? requestedSize : QSize(32, 32);

    // SHGetFileInfoW reads the same shell associations used by Explorer, so
    // DLL, XML, LOG, and other registered file types receive native icons.
    SHFILEINFOW fileInfo{};
    const QFileInfo inputInfo(path);
    const std::wstring nativePath = QDir::toNativeSeparators(inputInfo.absoluteFilePath()).toStdWString();
    const UINT flags = SHGFI_ICON | SHGFI_LARGEICON;
    bool found = SHGetFileInfoW(nativePath.c_str(), 0, &fileInfo, sizeof(fileInfo), flags) != 0;

    // Some virtual or recently-created files have no shell item yet. Asking
    // by attributes lets Windows resolve the icon from the file extension.
    if ((!found || !fileInfo.hIcon) && !nativePath.empty()) {
        if (fileInfo.hIcon) DestroyIcon(fileInfo.hIcon);
        fileInfo = {};
        found = SHGetFileInfoW(nativePath.c_str(), FILE_ATTRIBUTE_NORMAL, &fileInfo,
                               sizeof(fileInfo), flags | SHGFI_USEFILEATTRIBUTES) != 0;
    }

    // Last-resort generic text icon: never leave a regular file row blank.
    if ((!found || !fileInfo.hIcon)) {
        if (fileInfo.hIcon) DestroyIcon(fileInfo.hIcon);
        fileInfo = {};
        found = SHGetFileInfoW(L".txt", FILE_ATTRIBUTE_NORMAL, &fileInfo,
                               sizeof(fileInfo), flags | SHGFI_USEFILEATTRIBUTES) != 0;
    }

    const QPixmap pixmap = found ? pixmapFromHicon(fileInfo.hIcon, targetSize.width()) : QPixmap();
    if (fileInfo.hIcon)
        DestroyIcon(fileInfo.hIcon);
    if (size)
        *size = pixmap.size();
    return pixmap;
}
