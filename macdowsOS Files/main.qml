import QtQuick 6.5
import QtQuick.Window 6.5
import QtQuick.Controls 6.5
import QtQuick.Layouts 6.5
import Qt.labs.folderlistmodel 6.5
import macdowsOS.Locations 1.0

Window {
    id: window
    visible: true
    width: 1040
    height: 680
    minimumWidth: 760
    minimumHeight: 500
    title: "macdowsOS Files"
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowSystemMenuHint | Qt.WindowMinMaxButtonsHint

    QtObject {
        id: nav
        property string currentPath: FileLocations.homeUrl()
        property var historyStack: []
        property int historyIndex: -1

        function setCurrent(path) {
            currentPath = path
            sidebar.currentPath = path
        }
        function navigateTo(path, push) {
            var target = FileLocations.normalizeFolder(path)
            if (!target) return false
            if (push === undefined) push = true
            if (push) {
                if (historyIndex < historyStack.length - 1)
                    historyStack = historyStack.slice(0, historyIndex + 1)
                if (historyStack.length === 0 || historyStack[historyStack.length - 1] !== target) {
                    historyStack.push(target)
                    historyIndex = historyStack.length - 1
                }
            }
            setCurrent(target)
            return true
        }
        function goBack() {
            if (historyIndex > 0) {
                historyIndex--
                setCurrent(historyStack[historyIndex])
            }
        }
        function goForward() {
            if (historyIndex < historyStack.length - 1) {
                historyIndex++
                setCurrent(historyStack[historyIndex])
            }
        }
        function goUp() {
            var path = currentPath.replace("file:///", "")
            var slash = path.lastIndexOf("/")
            if (slash < 0) return
            var parent = path.slice(0, slash + 1)
            if (parent.length === 2 && parent[1] === ":") parent += "/"
            navigateTo(FileLocations.normalizeFolder(parent), true)
        }
    }

    FolderListModel {
        id: myFileModel
        folder: nav.currentPath
        showDirs: true
        showFiles: true
        showHidden: false
        nameFilters: ["*"]
        sortField: FolderListModel.Name
        sortCaseSensitive: false
        sortReversed: false
    }

    Rectangle {
        id: background
        anchors.fill: parent
        radius: 23
        color: "#212224"
        border.color: "#424448"
        border.width: 1
        clip: true

        RowLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 0

            Rectangle {
                id: leftPanel
                Layout.preferredWidth: 250
                Layout.fillHeight: true
                color: "#1C1D1F"
                radius: 16
                border.color: "#424448"
                border.width: 1

                MouseArea {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 46
                    z: 0
                    cursorShape: Qt.OpenHandCursor
                    onPressed: window.startSystemMove()
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 13
                    spacing: 12
                    z: 1

                    RowLayout {
                        Layout.fillWidth: true
                        height: 34
                        WindowControls {
                            Layout.preferredWidth: 72
                            onMinimizeClicked: window.showMinimized()
                            onMaximizeClicked: window.visibility === Window.Maximized ? window.showNormal() : window.showMaximized()
                            onCloseClicked: window.close()
                        }
                    }

                    SidebarList {
                        id: sidebar
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: FileLocations.sidebarModel
                        currentPath: nav.currentPath
                        onItemClicked: function(path) { nav.navigateTo(path, true) }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: "#35383d" }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8
                        spacing: 8
                        Text { text: "\uE8B7"; color: "#73a8ee"; font.family: "Segoe Fluent Icons"; font.pixelSize: 15 }
                        Text { Layout.fillWidth: true; text: myFileModel.count + " 个项目"; color: "#7e8794"; font.pixelSize: 11 }
                        Text { text: FileLocations.labelForUrl(nav.currentPath); color: "#6e7887"; font.pixelSize: 11; elide: Text.ElideMiddle }
                    }
                }
            }

            Rectangle {
                id: splitter
                Layout.fillHeight: true
                width: 5
                color: "transparent"
                property real startX: 0
                property real startWidth: 250
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SplitHCursor
                    onPressed: { splitter.startX = mouse.x; splitter.startWidth = leftPanel.Layout.preferredWidth }
                    onPositionChanged: {
                        var value = splitter.startWidth + mouse.x - splitter.startX
                        leftPanel.Layout.preferredWidth = Math.max(190, Math.min(window.width * 0.45, value))
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"

                MouseArea {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 46
                    z: 0
                    cursorShape: Qt.OpenHandCursor
                    onPressed: window.startSystemMove()
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12
                    z: 1

                    RowLayout {
                        Layout.fillWidth: true
                        height: 48
                        spacing: 6

                        Rectangle {
                            id: navigationPill
                            Layout.preferredWidth: 92
                            Layout.minimumWidth: 92
                            Layout.maximumWidth: 92
                            Layout.preferredHeight: 40
                            Layout.minimumHeight: 40
                            Layout.maximumHeight: 40
                            width: 92
                            height: 40
                            radius: 20
                            color: "#303136"
                            border.color: "#4d4f56"
                            border.width: 1
                            clip: true
                            Item {
                                width: 45
                                height: parent.height
                                opacity: nav.historyIndex > 0 ? 1 : 0.38
                                Rectangle { anchors.fill: parent; color: backMouse.containsMouse && backMouse.enabled ? "#41434a" : "transparent" }
                                Canvas {
                                    anchors.fill: parent
                                    onPaint: {
                                        var context = getContext("2d")
                                        context.clearRect(0, 0, width, height)
                                        context.strokeStyle = "#eef0f4"
                                        context.lineWidth = 1.9
                                        context.lineCap = "round"
                                        context.lineJoin = "round"
                                        context.beginPath()
                                        context.moveTo(width * 0.62, height * 0.35)
                                        context.lineTo(width * 0.43, height * 0.5)
                                        context.lineTo(width * 0.62, height * 0.65)
                                        context.stroke()
                                    }
                                }
                                MouseArea { id: backMouse; anchors.fill: parent; enabled: nav.historyIndex > 0; hoverEnabled: true; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: nav.goBack() }
                            }
                            Rectangle { x: 45; y: 9; width: 1; height: parent.height - 18; color: "#55575e" }
                            Item {
                                x: 46
                                width: 46
                                height: parent.height
                                opacity: nav.historyIndex < nav.historyStack.length - 1 ? 1 : 0.38
                                Rectangle { anchors.fill: parent; color: forwardMouse.containsMouse && forwardMouse.enabled ? "#41434a" : "transparent" }
                                Canvas {
                                    anchors.fill: parent
                                    onPaint: {
                                        var context = getContext("2d")
                                        context.clearRect(0, 0, width, height)
                                        context.strokeStyle = "#eef0f4"
                                        context.lineWidth = 1.9
                                        context.lineCap = "round"
                                        context.lineJoin = "round"
                                        context.beginPath()
                                        context.moveTo(width * 0.38, height * 0.35)
                                        context.lineTo(width * 0.57, height * 0.5)
                                        context.lineTo(width * 0.38, height * 0.65)
                                        context.stroke()
                                    }
                                }
                                MouseArea { id: forwardMouse; anchors.fill: parent; enabled: nav.historyIndex < nav.historyStack.length - 1; hoverEnabled: true; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: nav.goForward() }
                            }
                        }
                        Rectangle { width: 1; height: 22; color: "#3b3e43"; Layout.leftMargin: 5; Layout.rightMargin: 10 }
                        Text { text: "\uE8B7"; color: "#8cb7ff"; font.family: "Segoe Fluent Icons"; font.pixelSize: 17 }
                        Text {
                            Layout.fillWidth: true
                            text: FileLocations.labelForUrl(nav.currentPath)
                            color: "#f0f2f5"
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            elide: Text.ElideMiddle
                        }

                        Rectangle {
                            width: 76; height: 40; radius: 20
                            color: "#303136"; border.color: "#4d4f56"; border.width: 1
                            Row {
                                anchors.fill: parent
                                Item {
                                    width: 37; height: parent.height
                                    Rectangle { anchors.fill: parent; color: listModeMouse.containsMouse ? "#41434a" : "transparent" }
                                    Text { anchors.centerIn: parent; text: "\uE8FD"; color: "#e7e9ef"; font.family: "Segoe Fluent Icons"; font.pixelSize: 16 }
                                    MouseArea { id: listModeMouse; anchors.fill: parent; hoverEnabled: true; onClicked: myFileModel.sortField = FolderListModel.Name }
                                }
                                Rectangle { width: 1; height: 22; y: 9; color: "#55575e" }
                                Item {
                                    width: 37; height: parent.height
                                    Rectangle { anchors.fill: parent; color: gridModeMouse.containsMouse ? "#41434a" : "transparent" }
                                    Text { anchors.centerIn: parent; text: "\uE80A"; color: "#e7e9ef"; font.family: "Segoe Fluent Icons"; font.pixelSize: 16 }
                                    MouseArea { id: gridModeMouse; anchors.fill: parent; hoverEnabled: true; onClicked: { } }
                                }
                            }
                        }
                        Repeater {
                            model: ["\uE72D", "\uE8EC", "\uE712"]
                            delegate: Rectangle {
                                width: 38; height: 40; radius: 20
                                color: actionMouse.containsMouse ? "#41434a" : "#303136"
                                border.color: "#4d4f56"; border.width: 1
                                Text { anchors.centerIn: parent; text: modelData; color: "#e7e9ef"; font.family: "Segoe Fluent Icons"; font.pixelSize: 16 }
                                MouseArea { id: actionMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
                            }
                        }

                        Rectangle {
                            width: 220; height: 40; radius: 20
                            color: "#303136"
                            border.color: searchInput.activeFocus ? "#4c9bff" : "#4d4f56"
                            border.width: 1
                            Text { anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: "\uE721"; color: "#8e98a5"; font.family: "Segoe Fluent Icons"; font.pixelSize: 14 }
                            TextInput {
                                id: searchInput
                                anchors.left: parent.left; anchors.leftMargin: 30; anchors.right: parent.right; anchors.rightMargin: 8
                                height: parent.height
                                verticalAlignment: TextInput.AlignVCenter
                                color: "#e5e9ef"
                                font.pixelSize: 12
                                selectByMouse: true
                                onTextChanged: myFileModel.nameFilters = text.length ? ["*" + text + "*"] : ["*"]
                            }
                            Text { anchors.left: parent.left; anchors.leftMargin: 31; anchors.verticalCenter: parent.verticalCenter; text: "搜索"; color: "#7e8794"; font.pixelSize: 12; visible: !searchInput.text }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        height: 26
                        spacing: 0
                        Text { Layout.preferredWidth: 48; text: "" }
                        Text { Layout.fillWidth: true; text: "名称"; color: "#858a95"; font.pixelSize: 11 }
                        Text { Layout.preferredWidth: 110; text: "大小"; color: "#858a95"; font.pixelSize: 11; horizontalAlignment: Text.AlignRight }
                        Text { Layout.preferredWidth: 180; text: "修改日期"; color: "#858a95"; font.pixelSize: 11; horizontalAlignment: Text.AlignRight }
                    }

                    FileListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        fileModel: myFileModel
                        onFolderClicked: function(path) { nav.navigateTo(path, true) }
                        onFileClicked: function(path) { Qt.openUrlExternally(path) }
                    }
                }
            }
        }
    }

    Component.onCompleted: nav.navigateTo(FileLocations.homeUrl(), true)

    MouseArea { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 7; cursorShape: Qt.SizeHorCursor; onPressed: window.startSystemResize(Qt.LeftEdge) }
    MouseArea { anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 7; cursorShape: Qt.SizeHorCursor; onPressed: window.startSystemResize(Qt.RightEdge) }
    MouseArea { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; height: 7; cursorShape: Qt.SizeVerCursor; onPressed: window.startSystemResize(Qt.TopEdge) }
    MouseArea { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 7; cursorShape: Qt.SizeVerCursor; onPressed: window.startSystemResize(Qt.BottomEdge) }
}
