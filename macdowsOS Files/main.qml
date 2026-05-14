//Qt
import QtQuick 6.5
import QtQuick.Window 6.5
import QtQuick.Controls 6.5
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts 6.5 // 修复Layout报错的核心导入
import Qt.labs.folderlistmodel 6.5
// 应用程序主窗口，所有QML代码的根元素
Window {
    id: window

    // 窗口启动时是否可见，必须设为true否则窗口不会显示
    visible: true

    // 窗口初始宽度（像素）
    width: 900
    // 窗口初始高度（像素）
    height: 600

    // 窗口最小宽度，防止用户把窗口缩得太小
    minimumWidth: 640
    // 窗口最小高度
    minimumHeight: 480

    // 窗口标题，会显示在任务栏和Alt+Tab列表中
    title: "macdowsOS Files"

    // ==============================================
    // 窗口标志组合（最核心的部分，新手最容易踩坑）
    // ==============================================
    // Qt.Window：告诉系统这是一个顶级应用窗口，必须加！否则任务栏不显示
    // Qt.FramelessWindowHint：移除系统原生标题栏和边框
    // Qt.WindowSystemMenuHint：保留任务栏右键菜单（关闭、最大化等）
    // Qt.WindowMinMaxButtonsHint：保留系统对最小化/最大化的原生支持
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowSystemMenuHint | Qt.WindowMinMaxButtonsHint

    // 窗口背景色，这里设为纯白色，你可以改成任意颜色
    color: "transparent"
    //文件系统初始化
    // 文件数据模型（内置）
    FolderListModel {
        id: myFileModel
        folder: "file:///C:/"      // Windows 初始路径
        showDirs: true
        showFiles: true
        nameFilters: ["*"]
        sortField: FolderListModel.Name
    }
    // ==============================================
    // 导航历史管理（纯 JS 对象）
    // ==============================================
    QtObject {
        id: nav

        // 历史记录栈
        property var historyStack: []
        // 当前在栈中的位置
        property int historyIndex: -1

        // 跳转到指定路径
        function navigateTo(path) {
            // 如果当前位置不在栈顶，截断前进历史
            if (historyIndex < historyStack.length - 1)
                historyStack = historyStack.slice(0, historyIndex + 1)
            // 将新路径压入栈
            historyStack.push(path)
            historyIndex = historyStack.length - 1
            // 更新模型文件夹
            myFileModel.folder = path
        }

        // 后退
        function goBack() {
            if (historyIndex > 0) {
                historyIndex--
                myFileModel.folder = historyStack[historyIndex]
            }
        }

        // 前进
        function goForward() {
            if (historyIndex < historyStack.length - 1) {
                historyIndex++
                myFileModel.folder = historyStack[historyIndex]
            }
        }
    }

    // 初始化：将初始路径加入历史
    Component.onCompleted: nav.navigateTo(myFileModel.folder)

    Rectangle {
        id: background
        anchors.fill: parent
        radius: 23                 // 圆角半径，可自定义
        color: "#212224"             // 窗口整体背景色（28,29,31）
        //color: "transparent"
        border {
            color: "#424448"         // 边框颜色（66,68,72）
            width: 1                 // 边框粗细
        }
        
        //顶部拖动区域
        MouseArea {
            id: titleBarDragArea
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 80                     // 可拖动区域高度，你可以改成任意值
            cursorShape: Qt.OpenHandCursor // 鼠标移上去变成手型

            onPressed: {
                window.startSystemMove()   // 调用系统移动窗口功能
            }
        }
        // 窗口容器
        RowLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                id: leftPanel
                Layout.preferredWidth: 280
                Layout.fillHeight: true
                //Layout.rightMargin: 16
                Layout.leftMargin: 6
                Layout.topMargin: 6
                Layout.bottomMargin: 6
                color: "#1C1D1F"
                radius: 16
                border { 
                    color: "#424448"; 
                    width: 1 
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 13
                    spacing: 15

                    // 窗口控制按钮（红绿灯）
                    WindowControls {
                        Layout.fillWidth: true
                        onMinimizeClicked: window.showMinimized()
                        onMaximizeClicked: {
                            if (window.visibility === Window.Maximized)
                                window.showNormal()
                            else
                                window.showMaximized()
                        }
                        onCloseClicked: window.close()
                    }

                    SidebarList {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        sidebarModel: ListModel {
                            ListElement { name: "桌面"; path: "file:///C:/Users/Public/Desktop" }
                            ListElement { name: "文档"; path: "file:///C:/Users/Public/Documents" }
                            ListElement { name: "下载"; path: "file:///C:/Users/Public/Downloads" }
                            ListElement { name: "C:";    path: "file:///C:/" }
                        }
                        // 直接使用 path 参数
                        onItemClicked: nav.navigateTo(path)
                    }
                }
            }
            //拖动
            // ---------- 新增：可拖动的分割条 ----------
            Rectangle {
                id: splitter
                Layout.fillHeight: true
                width: 4
                color: "transparent" 
                //color:"black"
                // 透明，仅作为拖动热区

                // 拖动时需要缓存的变量
                property real startX: 0
                property real startWidth: 0
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SplitHCursor    // 水平分割光标
                    onPressed: {
                        // 记录按下时的全局横坐标和左侧当前宽度
                        splitter.startX = mouse.x
                        splitter.startWidth = leftPanel.Layout.preferredWidth
                    }
                    onPositionChanged: {
                        // 计算移动距离：当前鼠标坐标 - 按下坐标
                        var delta = mouse.x - splitter.startX
                        // 新宽度 = 原宽度 + 移动距离，并限制最小值
                        var newWidth = splitter.startWidth + delta
                        if (newWidth < 100) newWidth = 100   // 最小100px
                        if (newWidth > window.width * 0.8)   // 可选：最大不超过窗口80%
                        newWidth = window.width * 0.8
                        leftPanel.Layout.preferredWidth = newWidth
                    }
                }
            }
            // 右侧 空白区域 自动占满剩余宽度
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"
                //右侧文件列表
                // 右侧文件列表
                FileListView {
                    anchors.fill: parent
                    anchors.margins: 15
                    fileModel: myFileModel

                    // 直接使用隐式参数 path，无需箭头函数
                    onFolderClicked: nav.navigateTo(path)
                    onFileClicked: Qt.openUrlExternally(path)
                }
            }
        }
        
    }  
   
   // ==============================================
   // 系统原生窗口边缘缩放（8个方向全覆盖）
   // ==============================================
   MouseArea { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 8; cursorShape: Qt.SizeHorCursor; onPressed: window.startSystemResize(Qt.LeftEdge) }
   MouseArea { anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 8; cursorShape: Qt.SizeHorCursor; onPressed: window.startSystemResize(Qt.RightEdge) }
   MouseArea { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; height: 8; cursorShape: Qt.SizeVerCursor; onPressed: window.startSystemResize(Qt.TopEdge) }
   MouseArea { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 8; cursorShape: Qt.SizeVerCursor; onPressed: window.startSystemResize(Qt.BottomEdge) }
   MouseArea { anchors.left: parent.left; anchors.top: parent.top; width: 8; height: 8; cursorShape: Qt.SizeFDiagCursor; onPressed: window.startSystemResize(Qt.TopEdge | Qt.LeftEdge) }
   MouseArea { anchors.right: parent.right; anchors.top: parent.top; width: 8; height: 8; cursorShape: Qt.SizeBDiagCursor; onPressed: window.startSystemResize(Qt.TopEdge | Qt.RightEdge) }
   MouseArea { anchors.left: parent.left; anchors.bottom: parent.bottom; width: 8; height: 8; cursorShape: Qt.SizeBDiagCursor; onPressed: window.startSystemResize(Qt.BottomEdge | Qt.LeftEdge) }
   MouseArea { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 8; height: 8; cursorShape: Qt.SizeFDiagCursor; onPressed: window.startSystemResize(Qt.BottomEdge | Qt.RightEdge) }
}