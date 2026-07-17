// FileListView.qml
import QtQuick 6.5
import QtQuick.Controls 6.5

ListView {
    id: fileListView

    property alias fileModel: fileListView.model

    signal folderClicked(string path)
    signal fileClicked(string path)

    clip: true
    // 隐藏垂直滚动条，但仍可鼠标滚轮滑动
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOff }

    function formatSize(bytes) {
        if (bytes < 1024) return bytes + " B"
        else if (bytes < 1048576) return (bytes / 1024).toFixed(1) + " KB"
        else if (bytes < 1073741824) return (bytes / 1048576).toFixed(1) + " MB"
        else return (bytes / 1073741824).toFixed(1) + " GB"
    }

    delegate: ItemDelegate {
        id: delegateItem
        width: fileListView.width
        height: 42

        background: Rectangle {
            color: delegateItem.hovered ? "#2A2D30" : "transparent"
            radius: 4
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 1
                color: "#2E3136"
            }
        }

        contentItem: Row {
            anchors.fill: parent
            leftPadding: 12
            rightPadding: 12
            spacing: 12

            // 图标
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: model.fileIsDir ? "📁" : "📄"
                font.pixelSize: 20
                color: model.fileIsDir ? "#F2CA44" : "#7F8C8D"
            }

            // 文件名
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: model.fileName
                color: "#ECF0F1"
                font.pixelSize: 14
                elide: Text.ElideRight
                width: Math.max(80, parent.width - 300)
            }

            // 文件大小列（始终存在，文件夹时显示空字符串）
            Text {
                anchors.verticalCenter: parent.verticalCenter
                // 根据是否为目录决定显示内容：目录为空，文件为格式化大小
                text: model.fileIsDir ? "" : formatSize(model.fileSize)
                color: "#95A5A6"
                font.pixelSize: 13
                width: 50
                horizontalAlignment: Text.AlignRight
            }

            // 修改日期
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(model.fileModified, "yyyy-MM-dd hh:mm")
                color: "#95A5A6"
                font.pixelSize: 13
                width: 160
                horizontalAlignment: Text.AlignRight
            }
        }

        onClicked: {
            var targetPath = model.fileURL
            if (!targetPath || targetPath === "") {
                targetPath = model.filePath
            }
            if (typeof targetPath !== "string") {
                targetPath = targetPath.toString()
            }
            if (!targetPath || targetPath === "") {
                console.warn("FileListView: 无法获取文件路径")
                return
            }
            if (targetPath.indexOf("file:///") !== 0) {
                targetPath = "file:///" + targetPath
            }

            if (model.fileIsDir) {
                fileListView.folderClicked(targetPath)
            } else {
                fileListView.fileClicked(targetPath)
            }
        }
    }
}
