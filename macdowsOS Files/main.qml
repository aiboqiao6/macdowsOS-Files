import QtQuick 6.5
import QtQuick.Window 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5
import QtQuick.Effects 6.5
import Qt.labs.folderlistmodel 6.5
import macdowsOS.Locations 1.0

Window {
    id: window
    objectName: "finderWindow"
    visible: true
    width: 1220
    height: 820
    minimumWidth: 860
    minimumHeight: 540
    title: FileLocations.labelForUrl(nav.currentPath) + " — macdowsOS Files"
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowSystemMenuHint | Qt.WindowMinMaxButtonsHint
    property int sidebarWidth: 230
    property bool previewRequested: true
    property bool searchExpanded: false
    property bool statusBarVisible: false
    readonly property bool previewVisible: previewRequested && width >= 1060
    readonly property string currentIcon: {
        var entries = FileLocations.sidebarLocations()
        for (var i = 0; i < entries.length; ++i)
            if (entries[i].path === nav.currentPath) return entries[i].icon
        return "folder"
    }
    FinderTheme { id: theme }
    readonly property int windowCornerRadius: theme.cornerRadius
    onSidebarWidthChanged: NativeShell.attachWindow(window)

    QtObject {
        id: nav
        property string currentPath: FileLocations.homeUrl()
        property var historyStack: []
        property int historyIndex: -1
        function setCurrent(path) {
            currentPath = path
            files.clearSelection()
            pathInput.text = path
            searchInput.text = ""
        }
        function navigateTo(path, push) {
            var target = FileLocations.normalizeFolder(path)
            if (!target) return false
            if (push === undefined) push = true
            if (push && target !== historyStack[historyIndex]) {
                historyStack = historyStack.slice(0, historyIndex + 1).concat([target])
                historyIndex = historyStack.length - 1
            }
            setCurrent(target)
            return true
        }
        function goBack() { if (historyIndex > 0) { --historyIndex; setCurrent(historyStack[historyIndex]) } }
        function goForward() { if (historyIndex < historyStack.length - 1) { ++historyIndex; setCurrent(historyStack[historyIndex]) } }
        function goUp() { navigateTo(FileLocations.parentFolder(currentPath)) }
    }
    FolderListModel {
        id: folderModel
        objectName: "folderModel"
        folder: nav.currentPath
        showDirs: true
        showFiles: true
        showDotAndDotDot: false
        showHidden: false
        nameFilters: ["*"]
        showDirsFirst: true
        sortField: FolderListModel.Name
        sortCaseSensitive: false
    }
    FileFilterModel {
        id: filteredModel
        sourceModel: folderModel
        searchText: searchInput.text
    }

    Shortcut { sequence: "Alt+Left"; onActivated: nav.goBack() }
    Shortcut { sequence: "Alt+Right"; onActivated: nav.goForward() }
    Shortcut { sequence: "Alt+Up"; onActivated: nav.goUp() }
    Shortcut { sequence: "Ctrl+L"; onActivated: { pathInput.forceActiveFocus(); pathInput.selectAll() } }
    Shortcut { sequence: "Ctrl+F"; onActivated: { window.searchExpanded = true; searchInput.forceActiveFocus() } }
    Shortcut { sequence: "F5"; onActivated: filteredModel.refresh() }
    Shortcut { sequence: "Ctrl+1"; onActivated: files.iconView = true }
    Shortcut { sequence: "Ctrl+2"; onActivated: files.iconView = false }
    Shortcut { sequence: "Ctrl+Shift+P"; onActivated: window.previewRequested = !window.previewRequested }

    // Match the native input mask and alpha mask to one large silhouette.
    Rectangle {
        id: windowMask
        width: frame.width
        height: frame.height
        radius: window.visibility === Window.Maximized ? 0 : theme.cornerRadius
        layer.enabled: true
        visible: false
        color: "white"
    }
    Rectangle {
        id: frame
        anchors.fill: parent
        radius: windowMask.radius
        color: NativeShell.backdropAvailable ? "transparent" : theme.window
        layer.enabled: true
        layer.effect: MultiEffect { maskEnabled: true; maskSource: windowMask }

        Rectangle {
            id: sidebarPanel
            width: window.sidebarWidth
            height: parent.height
            color: NativeShell.backdropAvailable ? theme.sidebarGlass : theme.sidebar
            gradient: Gradient {
                GradientStop { position: 0; color: NativeShell.backdropAvailable && window.visibility === Window.Maximized ? theme.sidebarGlass : theme.sidebar }
                GradientStop { position: window.visibility === Window.Maximized ? 0 : theme.cornerRadius / sidebarPanel.height; color: NativeShell.backdropAvailable ? (window.visibility === Window.Maximized ? theme.sidebarGlass : theme.sidebar) : theme.sidebar }
                GradientStop { position: (theme.cornerRadius + 32) / sidebarPanel.height; color: NativeShell.backdropAvailable ? theme.sidebarGlass : theme.sidebar }
                GradientStop { position: 1 - (theme.cornerRadius + 32) / sidebarPanel.height; color: NativeShell.backdropAvailable ? theme.sidebarGlass : theme.sidebar }
                GradientStop { position: window.visibility === Window.Maximized ? 1 : 1 - theme.cornerRadius / sidebarPanel.height; color: NativeShell.backdropAvailable ? (window.visibility === Window.Maximized ? theme.sidebarGlass : theme.sidebar) : theme.sidebar }
                GradientStop { position: 1; color: NativeShell.backdropAvailable && window.visibility === Window.Maximized ? theme.sidebarGlass : theme.sidebar }
            }
            MouseArea { width: parent.width; height: theme.toolbarHeight; onPressed: window.startSystemMove(); onDoubleClicked: window.visibility === Window.Maximized ? window.showNormal() : window.showMaximized() }
            WindowControls {
                x: 24
                y: 24
                windowActive: window.active
                onMinimizeClicked: window.showMinimized()
                onMaximizeClicked: window.visibility === Window.Maximized ? window.showNormal() : window.showMaximized()
                onCloseClicked: window.close()
            }
            SidebarList {
                id: sidebar
                anchors.top: parent.top
                anchors.topMargin: theme.toolbarHeight
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 14
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                model: FileLocations.sidebarModel
                currentPath: nav.currentPath
                onItemClicked: function(path) { nav.navigateTo(path) }
            }
            Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: theme.separator }
        }

        Item {
            id: content
            anchors.left: sidebarPanel.right
            anchors.right: parent.right
            height: parent.height
            Rectangle { anchors.fill: parent; color: theme.window }

            Item {
                id: toolbar
                width: parent.width
                height: theme.toolbarHeight
                MouseArea { anchors.fill: parent; onPressed: window.startSystemMove(); onDoubleClicked: window.visibility === Window.Maximized ? window.showNormal() : window.showMaximized() }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8
                    GlassSurface {
                        Layout.preferredWidth: 86
                        Layout.preferredHeight: 42
                        Row {
                            anchors.centerIn: parent
                            FinderButton { width: 42; height: 40; capsule: false; iconName: "chevron-left"; tooltip: "后退 (Alt+←)"; enabled: nav.historyIndex > 0; onClicked: nav.goBack() }
                            Rectangle { width: 1; height: 23; y: 9; color: "#505050" }
                            FinderButton { width: 42; height: 40; capsule: false; iconName: "chevron-right"; tooltip: "前进 (Alt+→)"; enabled: nav.historyIndex < nav.historyStack.length - 1; onClicked: nav.goForward() }
                        }
                    }
                    LineIcon { visible: window.width >= 1000 && !window.searchExpanded; Layout.preferredWidth: 19; Layout.preferredHeight: 19; Layout.leftMargin: 7; name: window.currentIcon; color: window.currentIcon === "home" ? theme.accent : "#c8c8c8" }
                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 36
                        Layout.leftMargin: 2
                        text: FileLocations.labelForUrl(nav.currentPath)
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                        color: theme.text
                        elide: Text.ElideMiddle
                        visible: !window.searchExpanded || window.width > 1100
                    }
                    Item { visible: window.searchExpanded && window.width <= 1100; Layout.fillWidth: true }
                    GlassSurface {
                        visible: !window.searchExpanded || window.width > 1100
                        Layout.preferredWidth: 128
                        Layout.preferredHeight: 42
                        Row {
                            anchors.centerIn: parent
                            FinderButton { objectName: "gridButton"; width: 41; height: 36; capsule: false; checked: files.iconView; iconName: "grid"; tooltip: "图标视图 (Ctrl+1)"; onClicked: files.iconView = true }
                            FinderButton { objectName: "listButton"; width: 41; height: 36; capsule: false; checked: !files.iconView; iconName: "list"; tooltip: "列表视图 (Ctrl+2)"; onClicked: files.iconView = false }
                            FinderButton { width: 41; height: 36; capsule: false; checked: window.previewVisible; iconName: "preview"; tooltip: window.width < 1060 ? "加宽窗口以显示预览" : "显示或隐藏预览 (Ctrl+Shift+P)"; enabled: window.width >= 1060; onClicked: window.previewRequested = !window.previewRequested }
                        }
                    }
                    GlassSurface {
                        visible: !window.searchExpanded || window.width > 1100
                        Layout.preferredWidth: 54
                        Layout.preferredHeight: 42
                        FinderButton { width: 54; height: 42; capsule: false; iconName: "sort"; tooltip: "排序方式"; onClicked: sortMenu.popup(0, height + 6) }
                        LineIcon { x: 39; y: 17; width: 9; height: 9; name: "chevron-down"; color: "#dddddd" }
                        FinderMenu {
                            id: sortMenu
                            FinderMenuItem { text: "名称"; checkable: true; checked: folderModel.sortField === FolderListModel.Name; onTriggered: { folderModel.sortField = FolderListModel.Name; folderModel.sortReversed = false } }
                            FinderMenuItem { text: "种类"; checkable: true; checked: folderModel.sortField === FolderListModel.Type; onTriggered: { folderModel.sortField = FolderListModel.Type; folderModel.sortReversed = false } }
                            FinderMenuItem { text: "修改日期"; checkable: true; checked: folderModel.sortField === FolderListModel.Time; onTriggered: { folderModel.sortField = FolderListModel.Time; folderModel.sortReversed = true } }
                            FinderMenuItem { text: "大小"; checkable: true; checked: folderModel.sortField === FolderListModel.Size; onTriggered: { folderModel.sortField = FolderListModel.Size; folderModel.sortReversed = true } }
                            MenuSeparator { contentItem: Rectangle { implicitHeight: 1; color: "#555555" } }
                            FinderMenuItem { text: "倒序排列"; checkable: true; checked: folderModel.sortReversed; onTriggered: folderModel.sortReversed = !folderModel.sortReversed }
                        }
                    }
                    GlassSurface {
                        Layout.preferredWidth: window.width >= 1000 ? 86 : 44
                        Layout.preferredHeight: 42
                        Row {
                            anchors.centerIn: parent
                            FinderButton { visible: window.width >= 1000; width: 42; height: 40; capsule: false; iconName: "share"; tooltip: "文件操作"; enabled: files.selectedPath !== ""; onClicked: files.showContextMenu() }
                            FinderButton { width: 42; height: 40; capsule: false; iconName: "more"; tooltip: "更多选项"; onClicked: optionsMenu.popup(0, height + 6) }
                        }
                        FinderMenu {
                            id: optionsMenu
                            FinderMenuItem { text: "前往上一级 (Alt+↑)"; onTriggered: nav.goUp() }
                            FinderMenuItem { text: "在资源管理器中打开"; onTriggered: FileLocations.revealInFileManager(nav.currentPath) }
                            FinderMenuItem { text: "复制当前文件夹路径"; onTriggered: FileLocations.copyToClipboard(nav.currentPath) }
                            FinderMenuItem { text: "刷新 (F5)"; onTriggered: filteredModel.refresh() }
                            MenuSeparator { contentItem: Rectangle { implicitHeight: 1; color: "#555555" } }
                            FinderMenuItem { text: "显示隐藏文件"; checkable: true; checked: folderModel.showHidden; onTriggered: folderModel.showHidden = !folderModel.showHidden }
                            FinderMenuItem { text: "显示状态栏"; checkable: true; checked: window.statusBarVisible; onTriggered: window.statusBarVisible = !window.statusBarVisible }
                        }
                    }
                    GlassSurface {
                        Layout.preferredWidth: window.searchExpanded ? 210 : 42
                        Layout.preferredHeight: 42
                        highlighted: searchInput.activeFocus
                        FinderButton {
                            width: 42; height: 42; capsule: false; iconName: "search"; tooltip: "搜索当前文件夹 (Ctrl+F)"
                            onClicked: { window.searchExpanded = !window.searchExpanded; if (window.searchExpanded) searchInput.forceActiveFocus(); else searchInput.text = "" }
                        }
                        TextField {
                            id: searchInput
                            objectName: "searchInput"
                            visible: window.searchExpanded
                            anchors.left: parent.left; anchors.leftMargin: 39
                            anchors.right: parent.right; anchors.rightMargin: 10
                            height: parent.height
                            padding: 0
                            color: theme.text
                            placeholderText: "搜索当前文件夹"
                            placeholderTextColor: theme.secondaryText
                            font.pixelSize: 13
                            selectByMouse: true
                            background: Item {}
                            Keys.onEscapePressed: { text = ""; window.searchExpanded = false; files.forceActiveFocus() }
                        }
                    }
                }
            }

            Item {
                id: pathBar
                y: toolbar.height
                width: parent.width
                height: 48
                GlassSurface {
                    x: 10; y: 2
                    width: parent.width - 20
                    height: 32
                    highlighted: pathInput.activeFocus
                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 44
                        text: FileLocations.labelForUrl(nav.currentPath)
                        color: "#c1c1c1"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideMiddle
                        visible: !pathInput.activeFocus
                    }
                    TextInput {
                        id: pathInput
                        objectName: "pathInput"
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        verticalAlignment: TextInput.AlignVCenter
                        color: activeFocus ? theme.text : "transparent"
                        selectionColor: theme.selection
                        font.pixelSize: 12
                        selectByMouse: true
                        clip: true
                        onAccepted: {
                            if (nav.navigateTo(text)) { pathInput.color = Qt.binding(function() { return pathInput.activeFocus ? theme.text : "transparent" }); files.forceActiveFocus() }
                            else color = "#ff8c83"
                        }
                        Keys.onEscapePressed: { text = nav.currentPath; color = Qt.binding(function() { return pathInput.activeFocus ? theme.text : "transparent" }); files.forceActiveFocus() }
                        onActiveFocusChanged: if (activeFocus) { text = nav.currentPath; selectAll() }
                        Accessible.name: "文件夹路径"
                    }
                }
            }
            Rectangle {
                anchors.top: pathBar.bottom
                anchors.bottom: parent.bottom
                width: parent.width
                color: theme.content
                FileListView {
                    id: files
                    objectName: "fileBrowser"
                    anchors.top: parent.top
                    anchors.bottom: statusBar.top
                    width: parent.width - (window.previewVisible ? preview.width : 0)
                    fileModel: filteredModel
                    sourceModel: folderModel
                    currentFolder: nav.currentPath
                    searchText: searchInput.text
                    onFolderClicked: function(path) { nav.navigateTo(path) }
                    onFileClicked: function(path) { Qt.openUrlExternally(path) }
                }
                Rectangle {
                    id: preview
                    anchors.top: parent.top
                    anchors.bottom: statusBar.top
                    anchors.right: parent.right
                    width: Math.max(240, Math.min(300, content.width * 0.29))
                    visible: window.previewVisible
                    color: theme.window
                    Rectangle { width: 1; height: parent.height; color: theme.separator }
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 24
                        spacing: 14
                        visible: files.selectedPath !== ""
                        Item { Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 14 }
                        Image {
                            id: previewImage
                            Layout.fillWidth: true
                            Layout.preferredHeight: 180
                            source: files.selectedPath && !files.selectedIsDir && /\.(png|jpe?g|gif|webp|bmp)$/i.test(files.selectedName) ? files.selectedPath : ""
                            asynchronous: true
                            autoTransform: true
                            sourceSize.width: 600
                            sourceSize.height: 480
                            fillMode: Image.PreserveAspectFit
                            visible: status === Image.Ready
                        }
                        Image {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 96
                            Layout.preferredHeight: 96
                            source: !files.selectedPath ? "" : files.selectedIsDir ? "qrc:/icons/entity-folder.png" : files.fileIconSource(files.selectedPath)
                            sourceSize.width: 96
                            sourceSize.height: 96
                            fillMode: Image.PreserveAspectFit
                            visible: previewImage.status !== Image.Ready
                        }
                        Text { Layout.fillWidth: true; text: files.selectedName; color: theme.text; font.pixelSize: 16; font.weight: Font.DemiBold; wrapMode: Text.WrapAnywhere; maximumLineCount: 3; elide: Text.ElideMiddle; horizontalAlignment: Text.AlignHCenter }
                        Text { Layout.fillWidth: true; text: files.selectedKind + (files.selectedIsDir ? "" : " · " + files.selectedSize); color: theme.secondaryText; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap }
                        Rectangle { Layout.fillWidth: true; height: 1; color: theme.separator; Layout.topMargin: 12 }
                        Text { text: "修改日期"; color: theme.secondaryText; font.pixelSize: 11 }
                        Text { Layout.fillWidth: true; text: files.selectedModified; color: theme.text; font.pixelSize: 12; wrapMode: Text.Wrap }
                        Item { Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 14 }
                    }
                    Text { anchors.bottom: parent.bottom; anchors.bottomMargin: 20; anchors.horizontalCenter: parent.horizontalCenter; text: "选择文件以查看预览"; color: theme.mutedText; font.pixelSize: 11; visible: files.selectedPath === "" }
                }
                Rectangle {
                    id: statusBar
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: window.statusBarVisible ? 28 : 0
                    visible: window.statusBarVisible
                    color: theme.window
                    Rectangle { width: parent.width; height: 1; color: theme.separator }
                    Text { anchors.centerIn: parent; text: files.count + " 个项目" + (files.selectedPath ? "，已选中 1 个" : ""); color: theme.secondaryText; font.pixelSize: 11 }
                }
            }
        }
        // A narrow hit target changes the sidebar width without moving the window.
        MouseArea {
            x: window.sidebarWidth - 3; width: 6; height: parent.height
            property real previousX
            cursorShape: Qt.SplitHCursor
            onPressed: function(mouse) { previousX = mapToItem(frame, mouse.x, mouse.y).x }
            onPositionChanged: function(mouse) {
                if (!pressed) return
                var currentX = mapToItem(frame, mouse.x, mouse.y).x
                window.sidebarWidth = Math.max(190, Math.min(300, window.sidebarWidth + currentX - previousX))
                previousX = currentX
            }
        }
        Rectangle { anchors.fill: parent; visible: window.visibility !== Window.Maximized; radius: frame.radius; color: "transparent"; border.color: "#494949"; border.width: 1 }
    }
    Connections {
        target: NativeShell
        function onRenameRequested(path, name) {
            renameDialog.targetPath = path
            renameInput.text = name
            renameDialog.open()
            renameInput.forceActiveFocus()
            var dot = name.lastIndexOf(".")
            renameInput.select(0, dot > 0 ? dot : name.length)
        }
        function onOperationFailed(message) {
            operationDialog.message = message
            operationDialog.open()
        }
    }
    Dialog {
        id: renameDialog
        property string targetPath
        title: "重命名"
        x: (window.width - width) / 2
        y: (window.height - height) / 2
        width: 360
        modal: true
        palette.windowText: theme.text
        palette.buttonText: theme.text
        palette.button: "#454545"
        standardButtons: Dialog.Ok | Dialog.Cancel
        background: Rectangle { color: "#323232"; radius: 14; border.color: "#606060" }
        contentItem: TextField {
            id: renameInput
            selectByMouse: true
            color: theme.text
            font.pixelSize: 14
            background: Rectangle { color: theme.content; radius: 6; border.color: renameInput.activeFocus ? theme.accent : theme.separator }
            onAccepted: renameDialog.accept()
        }
        onAccepted: {
            if (!NativeShell.renameItem(targetPath, renameInput.text)) {
                operationDialog.message = "无法重命名该项目。请检查名称和文件权限。"
                operationDialog.open()
            }
        }
    }
    Dialog {
        id: operationDialog
        property string message
        title: "文件操作"
        x: (window.width - width) / 2
        y: (window.height - height) / 2
        width: 380
        modal: true
        palette.windowText: theme.text
        palette.buttonText: theme.text
        palette.button: "#454545"
        standardButtons: Dialog.Ok
        background: Rectangle { color: "#323232"; radius: 14; border.color: "#606060" }
        contentItem: Text { text: operationDialog.message; wrapMode: Text.Wrap; color: theme.text; font.pixelSize: 13 }
    }
    Component.onCompleted: {
        NativeShell.attachWindow(window)
        nav.navigateTo(FileLocations.homeUrl())
    }

    // Edge and corner targets retain native resizing for the frameless window.
    Repeater {
        model: [Qt.LeftEdge, Qt.RightEdge, Qt.TopEdge, Qt.BottomEdge,
                Qt.TopEdge | Qt.LeftEdge, Qt.TopEdge | Qt.RightEdge,
                Qt.BottomEdge | Qt.LeftEdge, Qt.BottomEdge | Qt.RightEdge]
        delegate: MouseArea {
            required property int modelData
            readonly property bool isLeft: (modelData & Qt.LeftEdge) !== 0
            readonly property bool isRight: (modelData & Qt.RightEdge) !== 0
            readonly property bool isTop: (modelData & Qt.TopEdge) !== 0
            readonly property bool isBottom: (modelData & Qt.BottomEdge) !== 0
            x: isRight ? window.width - width : 0
            y: isBottom ? window.height - height : 0
            width: isLeft || isRight ? 5 : window.width
            height: isTop || isBottom ? 5 : window.height
            enabled: window.visibility !== Window.Maximized
            cursorShape: (isLeft && isTop) || (isRight && isBottom) ? Qt.SizeFDiagCursor : (isRight && isTop) || (isLeft && isBottom) ? Qt.SizeBDiagCursor : isLeft || isRight ? Qt.SizeHorCursor : Qt.SizeVerCursor
            onPressed: window.startSystemResize(modelData)
        }
    }
}
