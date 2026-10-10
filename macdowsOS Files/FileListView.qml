import QtQuick 6.5
import QtQuick.Controls 6.5
import Qt.labs.folderlistmodel 6.5
import macdowsOS.Locations 1.0

Item {
    id: root
    property var fileModel
    property var sourceModel
    property string currentFolder: ""
    property string searchText: ""
    property FinderTheme theme: FinderTheme {}
    property bool iconView: false
    property int selectedIndex: -1
    property string selectedPath: ""
    property string selectedName: ""
    property string selectedKind: ""
    property string selectedSize: ""
    property string selectedModified: ""
    property bool selectedIsDir: false
    readonly property int count: fileModel ? fileModel.count : 0
    readonly property real nameWidth: Math.floor((width - 28) * 0.46)
    readonly property real kindWidth: Math.floor((width - 28) * 0.23)
    readonly property real dateWidth: width - 28 - nameWidth - kindWidth
    signal folderClicked(string path)
    signal fileClicked(string path)

    function formatSize(bytes) {
        if (bytes < 1024) return bytes + " B"
        if (bytes < 1048576) return (bytes / 1024).toFixed(1) + " KB"
        if (bytes < 1073741824) return (bytes / 1048576).toFixed(1) + " MB"
        return (bytes / 1073741824).toFixed(1) + " GB"
    }
    function kindLabel(name, isDir) {
        if (isDir) return "文件夹"
        var suffix = name.slice(name.lastIndexOf(".") + 1).toLowerCase()
        var kinds = { txt: "纯文本文稿", md: "Markdown 文稿", html: "HTML 文稿", htm: "HTML 文稿",
            pdf: "PDF 文稿", docx: "Word 文稿", pptx: "PowerPoint 演示文稿", xlsx: "Excel 工作簿",
            png: "PNG 图像", jpg: "JPEG 图像", jpeg: "JPEG 图像", webp: "WebP 图像", gif: "GIF 图像",
            mp4: "MPEG-4 影片", mov: "QuickTime 影片", mp3: "MP3 音频", zip: "ZIP 压缩归档",
            exe: "Windows 应用程序", jar: "Java JAR 文件", sh: "Shell Script", qml: "QML 文稿" }
        return kinds[suffix] || (name.lastIndexOf(".") > 0 ? suffix.toUpperCase() + " 文件" : "文件")
    }
    function formatDate(value) {
        var date = new Date(value)
        if (isNaN(date.getTime())) return "—"
        var today = new Date()
        var midnight = new Date(today.getFullYear(), today.getMonth(), today.getDate())
        var days = Math.floor((midnight.getTime() - new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime()) / 86400000)
        if (days >= 0 && days <= 2)
            return ["今天", "昨天", "前天"][days] + " " + Qt.formatDateTime(date, "hh:mm")
        return Qt.formatDateTime(date, "yyyy年M月d日 hh:mm")
    }
    function fileIconSource(url) { return "image://file-icons/" + encodeURIComponent(String(url)) }
    function clearSelection() {
        selectedIndex = -1
        selectedPath = ""
        selectedName = ""
        selectedKind = ""
        selectedSize = ""
        selectedModified = ""
        selectedIsDir = false
    }
    function select(index) {
        if (!fileModel || index < 0 || index >= count) { clearSelection(); return }
        selectedIndex = index
        selectedPath = String(fileModel.get(index, "fileUrl"))
        selectedName = fileModel.get(index, "fileName")
        selectedIsDir = fileModel.isFolder(index)
        selectedKind = kindLabel(selectedName, selectedIsDir)
        selectedSize = selectedIsDir ? "—" : formatSize(fileModel.get(index, "fileSize"))
        selectedModified = formatDate(fileModel.get(index, "fileModified"))
    }
    function openSelected() {
        if (!selectedPath) return
        var path = selectedPath
        if (selectedIsDir) { clearSelection(); folderClicked(path) }
        else fileClicked(path)
    }
    function sortBy(field) {
        clearSelection()
        if (sourceModel.sortField === field) sourceModel.sortReversed = !sourceModel.sortReversed
        else { sourceModel.sortField = field; sourceModel.sortReversed = false }
    }
    function showContextMenu() {
        var y = iconView ? 40 : Math.max(0, Math.min(height - 20, 40 + Math.max(0, selectedIndex) * theme.rowHeight - list.contentY))
        showNativeMenu(root, 32, y, selectedPath === "")
    }
    function showNativeMenu(anchor, x, y, background) {
        NativeShell.showContextMenu(background ? currentFolder : selectedPath, anchor, x, y, background)
    }
    function moveSelection(amount) {
        if (!count) return
        select(Math.max(0, Math.min(count - 1, selectedIndex < 0 ? 0 : selectedIndex + amount)))
        if (iconView) grid.positionViewAtIndex(selectedIndex, GridView.Contain)
        else list.positionViewAtIndex(selectedIndex, ListView.Contain)
    }
    focus: true
    Keys.onUpPressed: moveSelection(iconView ? -Math.max(1, Math.floor(grid.width / grid.cellWidth)) : -1)
    Keys.onDownPressed: moveSelection(iconView ? Math.max(1, Math.floor(grid.width / grid.cellWidth)) : 1)
    Keys.onLeftPressed: { if (iconView) moveSelection(-1) }
    Keys.onRightPressed: { if (iconView) moveSelection(1) }
    Keys.onReturnPressed: openSelected()
    Keys.onEnterPressed: openSelected()
    Keys.onEscapePressed: clearSelection()
    Keys.onMenuPressed: showContextMenu()
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier)) {
            showContextMenu()
            event.accepted = true
        }
    }
    Connections {
        target: root.sourceModel
        function onFolderChanged() { root.clearSelection(); list.positionViewAtBeginning(); grid.positionViewAtBeginning() }
        function onNameFiltersChanged() { root.clearSelection() }
        function onSortFieldChanged() { root.clearSelection() }
        function onSortReversedChanged() { root.clearSelection() }
        function onShowHiddenChanged() { root.clearSelection() }
        function onCountChanged() { root.clearSelection() }
    }
    onSearchTextChanged: clearSelection()
    Connections {
        target: root.fileModel
        function onCountChanged() { root.clearSelection() }
    }

    Rectangle {
        id: header
        visible: !root.iconView
        width: root.width
        height: visible ? 34 : 0
        color: root.theme.content
        Row {
            x: 14
            height: parent.height
            Repeater {
                model: [ { label: "名称", field: FolderListModel.Name, size: root.nameWidth },
                         { label: "种类", field: FolderListModel.Type, size: root.kindWidth },
                         { label: "修改日期", field: FolderListModel.Time, size: root.dateWidth } ]
                delegate: Item {
                    required property var modelData
                    required property int index
                    width: modelData.size
                    height: header.height
                    Rectangle { visible: index > 0; width: 1; height: 18; anchors.verticalCenter: parent.verticalCenter; color: "#424242" }
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: index === 0 ? 43 : 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        font.pixelSize: 12
                        font.weight: root.sourceModel && root.sourceModel.sortField === modelData.field ? Font.DemiBold : Font.Normal
                        color: root.sourceModel && root.sourceModel.sortField === modelData.field ? root.theme.text : root.theme.secondaryText
                    }
                    LineIcon {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 12; height: 12
                        visible: root.sourceModel && root.sourceModel.sortField === modelData.field
                        name: root.sourceModel && root.sourceModel.sortReversed ? "chevron-down" : "chevron-up"
                        color: root.theme.secondaryText
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.sortBy(modelData.field) }
                }
            }
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.theme.separator }
    }

    // Both views use the same selection and activation controller.
    component FileImage: Item {
        property string path
        property bool directory
        Image {
            id: asset
            anchors.fill: parent
            source: parent.directory ? "qrc:/icons/entity-folder.png" : root.fileIconSource(parent.path)
            sourceSize.width: 64
            sourceSize.height: 64
            fillMode: Image.PreserveAspectFit
        }
        LineIcon { anchors.fill: parent; visible: asset.status === Image.Error; name: parent.directory ? "folder" : "file"; color: "#4bbaff" }
    }

    ListView {
        id: list
        objectName: "fileList"
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        width: parent.width
        topMargin: 5
        bottomMargin: 8
        visible: !root.iconView
        model: visible ? root.fileModel : null
        clip: true
        currentIndex: root.selectedIndex
        keyNavigationEnabled: false
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 7 }
        delegate: Item {
            id: row
            required property int index
            required property string fileName
            required property url fileUrl
            required property bool fileIsDir
            required property date fileModified
            width: list.width
            height: root.theme.rowHeight
            readonly property bool selected: root.selectedIndex === index
            Rectangle {
                x: 13; width: parent.width - 26; height: parent.height - 1
                radius: 8
                color: row.selected ? root.theme.selection : rowMouse.containsMouse ? "#363636" : row.index % 2 ? root.theme.stripe : "transparent"
            }
            Row {
                x: 14
                height: parent.height
                Item {
                    width: root.nameWidth
                    height: parent.height
                    LineIcon { x: 6; anchors.verticalCenter: parent.verticalCenter; width: 10; height: 10; name: "chevron-right"; color: row.selected ? "white" : "#999999"; visible: row.fileIsDir }
                    FileImage { x: 22; anchors.verticalCenter: parent.verticalCenter; width: 18; height: 18; path: String(row.fileUrl); directory: row.fileIsDir }
                    Text { x: 46; width: parent.width - 54; anchors.verticalCenter: parent.verticalCenter; text: row.fileName; color: row.selected ? "white" : root.theme.text; font.pixelSize: 14; elide: Text.ElideMiddle }
                }
                Text { width: root.kindWidth; height: parent.height; leftPadding: 8; rightPadding: 8; verticalAlignment: Text.AlignVCenter; text: root.kindLabel(row.fileName, row.fileIsDir); color: row.selected ? "white" : root.theme.secondaryText; font.pixelSize: 14; elide: Text.ElideMiddle }
                Text { width: root.dateWidth; height: parent.height; leftPadding: 8; rightPadding: 8; verticalAlignment: Text.AlignVCenter; text: root.formatDate(row.fileModified); color: row.selected ? "white" : root.theme.secondaryText; font.pixelSize: 14; elide: Text.ElideRight }
            }
            MouseArea {
                id: rowMouse
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                hoverEnabled: true
                onClicked: function(mouse) { root.forceActiveFocus(); root.select(row.index); if (mouse.button === Qt.RightButton) root.showNativeMenu(row, mouse.x, mouse.y, false) }
                onDoubleClicked: function(mouse) { if (mouse.button === Qt.LeftButton) { root.select(row.index); root.openSelected() } }
            }
        }
        MouseArea {
            parent: list.contentItem
            y: list.contentHeight
            width: list.width
            height: Math.max(0, list.height + list.contentY - y)
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function(mouse) { root.clearSelection(); root.forceActiveFocus(); if (mouse.button === Qt.RightButton) root.showNativeMenu(this, mouse.x, mouse.y, true) }
        }
    }
    GridView {
        id: grid
        objectName: "fileGrid"
        anchors.fill: parent
        anchors.margins: 14
        visible: root.iconView
        model: visible ? root.fileModel : null
        cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 116)))
        cellHeight: 112
        currentIndex: root.selectedIndex
        keyNavigationEnabled: false
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 7 }
        delegate: Item {
            id: tile
            required property int index
            required property string fileName
            required property url fileUrl
            required property bool fileIsDir
            width: grid.cellWidth
            height: grid.cellHeight
            Rectangle { anchors.fill: parent; anchors.margins: 4; radius: 10; color: root.selectedIndex === tile.index ? "#304763" : tileMouse.containsMouse ? "#303030" : "transparent" }
            FileImage { anchors.horizontalCenter: parent.horizontalCenter; y: 12; width: 54; height: 54; path: String(tile.fileUrl); directory: tile.fileIsDir }
            Text { x: 8; y: 73; width: parent.width - 16; height: 32; text: tile.fileName; color: root.theme.text; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WrapAnywhere; maximumLineCount: 2; elide: Text.ElideRight }
            MouseArea {
                id: tileMouse
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                hoverEnabled: true
                onClicked: function(mouse) { root.forceActiveFocus(); root.select(tile.index); if (mouse.button === Qt.RightButton) root.showNativeMenu(tile, mouse.x, mouse.y, false) }
                onDoubleClicked: function(mouse) { if (mouse.button === Qt.LeftButton) { root.select(tile.index); root.openSelected() } }
            }
        }
        MouseArea {
            parent: grid.contentItem
            y: grid.contentHeight
            width: grid.width
            height: Math.max(0, grid.height + grid.contentY - y)
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function(mouse) { root.clearSelection(); root.forceActiveFocus(); if (mouse.button === Qt.RightButton) root.showNativeMenu(this, mouse.x, mouse.y, true) }
        }
    }
    Column {
        anchors.centerIn: parent
        spacing: 12
        visible: root.count === 0
        LineIcon { anchors.horizontalCenter: parent.horizontalCenter; width: 42; height: 42; name: "folder"; color: "#626262"; strokeWidth: 1.3 }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.sourceModel && root.sourceModel.status === FolderListModel.Loading ? "正在载入…" : root.searchText.length ? "没有找到匹配的文件" : "此文件夹为空"; color: root.theme.secondaryText; font.pixelSize: 13 }
    }
}
