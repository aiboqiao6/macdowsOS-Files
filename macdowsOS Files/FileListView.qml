// FileListView.qml
import QtQuick 6.5
import QtQuick.Controls 6.5
import macdowsOS.Locations 1.0

/* Finder-style right-hand list: selection, activation, native file icons, and menu. */
ListView {
    id: fileListView

    // The model is injected by main.qml so this component remains reusable.
    property alias fileModel: fileListView.model
    property int selectedIndex: -1
    property string selectedPath: ""
    property bool selectedIsDir: false

    signal folderClicked(string path)
    signal fileClicked(string path)

    clip: true
    // 隐藏垂直滚动条，但仍可鼠标滚轮滑动
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOff }

    // Presentation helpers keep formatting out of the delegate markup.
    function formatSize(bytes) {
        if (bytes < 1024) return bytes + " B"
        else if (bytes < 1048576) return (bytes / 1024).toFixed(1) + " KB"
        else if (bytes < 1073741824) return (bytes / 1048576).toFixed(1) + " MB"
        else return (bytes / 1073741824).toFixed(1) + " GB"
    }

    function kindLabel(fileName, isDir) {
        if (isDir) return "文件夹"
        var dot = fileName.lastIndexOf(".")
        if (dot > 0 && dot < fileName.length - 1)
            return fileName.slice(dot + 1).toUpperCase() + " 文件"
        return "文件"
    }

    // Regular files use Windows Shell icons; folders use the bundled entity asset.
    function fileIconSource(url, fallback) {
        var value = url || fallback
        if (!value) return ""
        if (typeof value !== "string") value = value.toString()
        return "image://file-icons/" + encodeURIComponent(value)
    }

    function normalizeItemPath(url, fallback) {
        var targetPath = url || fallback
        if (!targetPath) return ""
        if (typeof targetPath !== "string") targetPath = targetPath.toString()
        if (targetPath.indexOf("file:///") !== 0)
            targetPath = "file:///" + targetPath
        return targetPath
    }

    function openPath(path, isDir) {
        if (!path) return
        if (isDir) {
            fileListView.clearSelection()
            fileListView.folderClicked(path)
        }
        else fileListView.fileClicked(path)
    }

    function clearSelection() {
        fileListView.currentIndex = -1
        fileListView.selectedIndex = -1
        fileListView.selectedPath = ""
        fileListView.selectedIsDir = false
    }

    // Finder clears selection when navigation changes the current model folder.
    Connections {
        target: fileListView.fileModel
        function onFolderChanged() { fileListView.clearSelection() }
    }

    // One shared menu avoids creating a Popup for every recycled delegate.
    Menu {
        id: contextMenu
        implicitWidth: 286
        padding: 8
        topMargin: 4
        bottomMargin: 4
        modal: true

        // Finder-like dark translucent panel with a restrained border.
        background: Rectangle {
            color: "#3e3f45"
            radius: 17
            border.color: "#6b6d75"
            border.width: 1
        }

        // Keep every action on a stable row so the popup does not jump while
        // enabled states or hover feedback change.
        delegate: MenuItem {
            id: menuDelegate
            implicitHeight: 38
            leftPadding: 14
            rightPadding: 14
            topPadding: 0
            bottomPadding: 0

            contentItem: Text {
                text: menuDelegate.text
                color: menuDelegate.enabled ? "#f2f3f6" : "#8e9097"
                font.pixelSize: 14
                font.weight: Font.Medium
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            background: Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: 9
                color: menuDelegate.highlighted ? "#0a64d8" : "transparent"
            }
        }

        MenuItem {
            text: fileListView.selectedIsDir ? "打开文件夹" : "打开"
            enabled: fileListView.selectedPath !== ""
            onTriggered: fileListView.openPath(fileListView.selectedPath, fileListView.selectedIsDir)
        }
        MenuItem {
            text: "在资源管理器中显示"
            enabled: fileListView.selectedPath !== ""
            onTriggered: FileLocations.revealInFileManager(fileListView.selectedPath)
        }
        MenuSeparator {
            topPadding: 4
            bottomPadding: 4
            contentItem: Rectangle {
                implicitHeight: 1
                color: "#65676e"
            }
        }
        MenuItem {
            text: "复制路径"
            enabled: fileListView.selectedPath !== ""
            onTriggered: FileLocations.copyToClipboard(fileListView.selectedPath)
        }
        MenuItem {
            text: "刷新"
            onTriggered: {
                if (fileListView.fileModel && fileListView.fileModel.refresh)
                    fileListView.fileModel.refresh()
            }
        }
    }

    // Delegate columns mirror the header: arrow, icon, name, size, date, kind.
    delegate: ItemDelegate {
        id: delegateItem
        width: fileListView.width
        height: 46
        property bool selected: fileListView.currentIndex === index
        function itemPath() {
            return fileListView.normalizeItemPath(model.fileURL, model.filePath)
        }

        // Selection and pressed states are separate so click feedback remains visible.
        background: Rectangle {
            anchors.fill: parent
            anchors.topMargin: 2
            anchors.bottomMargin: 2
            color: delegateItem.selected ? (itemMouse.pressed ? "#0b74ed" : "#0a64d8") : itemMouse.pressed ? "#343941" : itemMouse.containsMouse ? "#2A2D30" : "transparent"
            radius: 13
            border.color: delegateItem.selected ? "#2182f0" : "transparent"
            border.width: delegateItem.selected ? 1 : 0
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 1
                color: delegateItem.selected ? "transparent" : "#2E3136"
            }
        }

        contentItem: Row {
            anchors.fill: parent
            leftPadding: 8
            rightPadding: 12
            spacing: 10

            // The arrow reserves width for folders and keeps file rows aligned.
            Item {
                width: 14
                height: 18
                anchors.verticalCenter: parent.verticalCenter
                LineIcon {
                    anchors.fill: parent
                    name: "chevron-right"
                    color: delegateItem.selected ? "#ffffff" : "#73b8ff"
                    visible: model.fileIsDir
                }
            }

            // Use the filled macOS-style file assets with a vector fallback.
            // Native file icon with a bundled generic-document fallback.
            Item {
                width: 28
                height: 28
                anchors.verticalCenter: parent.verticalCenter
                Image {
                    id: fileAsset
                    anchors.fill: parent
                    source: model.fileIsDir ? "qrc:/icons/entity-folder.png" : fileListView.fileIconSource(model.fileURL, model.filePath)
                    sourceSize.width: 32
                    sourceSize.height: 32
                    fillMode: Image.PreserveAspectFit
                    opacity: 1
                }
                Image {
                    anchors.fill: parent
                    source: "qrc:/icons/entity-file.png"
                    sourceSize.width: 32
                    sourceSize.height: 32
                    fillMode: Image.PreserveAspectFit
                    visible: !model.fileIsDir && fileAsset.status !== Image.Ready
                }
                LineIcon {
                    anchors.fill: parent
                    name: model.fileIsDir ? "folder" : "file"
                    color: model.fileIsDir ? "#45b7f5" : "#e8edf4"
                    visible: model.fileIsDir && fileAsset.status !== Image.Ready
                }
            }

            // 文件名
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: model.fileName
                color: delegateItem.selected ? "#ffffff" : "#ECF0F1"
                font.pixelSize: 14
                elide: Text.ElideRight
                width: Math.max(80, parent.width - 432)
            }

            // 文件大小列（始终存在，文件夹时显示空字符串）
            Text {
                anchors.verticalCenter: parent.verticalCenter
                // 根据是否为目录决定显示内容：目录为空，文件为格式化大小
                text: model.fileIsDir ? "--" : formatSize(model.fileSize)
                color: delegateItem.selected ? "#ffffff" : "#95A5A6"
                font.pixelSize: 13
                width: 80
                horizontalAlignment: Text.AlignRight
            }

            // 修改日期
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(model.fileModified, "yyyy年M月d日 hh:mm")
                color: delegateItem.selected ? "#ffffff" : "#95A5A6"
                font.pixelSize: 13
                width: 150
                horizontalAlignment: Text.AlignRight
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: kindLabel(model.fileName, model.fileIsDir)
                color: delegateItem.selected ? "#ffffff" : "#95A5A6"
                font.pixelSize: 13
                width: 90
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
            }
        }

        // Single click selects; double click activates; right click selects and opens menu.
        MouseArea {
            id: itemMouse
            anchors.fill: parent
            z: 3
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: function(mouse) {
                fileListView.currentIndex = index
                fileListView.selectedIndex = index
                fileListView.selectedPath = delegateItem.itemPath()
                fileListView.selectedIsDir = model.fileIsDir
                if (mouse.button === Qt.RightButton)
                    contextMenu.popup()
            }

            onDoubleClicked: function(mouse) {
                if (mouse.button === Qt.LeftButton)
                    fileListView.openPath(delegateItem.itemPath(), model.fileIsDir)
            }
        }
    }
}
