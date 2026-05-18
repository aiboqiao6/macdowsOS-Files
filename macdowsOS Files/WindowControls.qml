//红绿灯
// 导入Qt Quick核心模块，版本6.5
import QtQuick 6.5

// 使用Row布局容器，将三个按钮水平排列
Row {
    // 组件根元素ID，用于内部引用和外部访问
    id: root
    
    // 按钮之间的水平间距（macOS原生约为8px，这里设为10px更美观）
    spacing: 10

    // ------------------------------
    // 对外暴露的信号接口
    // 父组件通过连接这些信号来实现窗口控制逻辑
    // ------------------------------
    // 最小化按钮点击信号
    signal minimizeClicked()
    // 最大化/还原按钮点击信号
    signal maximizeClicked()
    // 关闭按钮点击信号
    signal closeClicked()

    // ================================================================
    // 1. 关闭按钮（红色）- macOS窗口控制最左侧按钮
    // ================================================================
    // 使用Item作为按钮容器，统一管理尺寸和子元素
    Item {
        // 按钮固定宽度（macOS原生按钮尺寸为16x16）
        width: 16
        // 按钮固定高度
        height: 16

        // ------------------------------
        // 圆形背景层
        // ------------------------------
        Rectangle {
            // 背景元素ID，用于内部引用
            id: closeBg
            // 填充整个父容器
            anchors.fill: parent
            // 设置圆角为宽度的一半，实现完美圆形
            radius: width / 2
            // macOS关闭按钮标准红色 (#E66562)
            color: "#E66562"
        }

        // ------------------------------
        // 关闭符号层（✕）
        // 平时透明，鼠标悬停时平滑显示
        // ------------------------------
        Text {
            // 文字在父容器中居中显示
            anchors.centerIn: parent
            // 关闭符号（使用Unicode字符✕，比字母X更美观）
            text: "✕"
            // 符号颜色（深暗红色，与红色背景形成对比）
            color: "#921E15"
            // 字体像素大小
            font.pixelSize: 12
            // 加粗显示，增强视觉效果
            font.bold: true
            // 透明度：鼠标悬停时为1（完全可见），否则为0（完全透明）
            opacity: closeMouse.containsMouse ? 1 : 0
            // 透明度变化动画：100毫秒平滑过渡
            Behavior on opacity { 
                NumberAnimation { 
                    duration: 100 
                } 
            }
        }

        // ------------------------------
        // 鼠标交互区域
        // ------------------------------
        MouseArea {
            // 鼠标区域ID，用于检测鼠标是否悬停
            id: closeMouse
            // 填充整个父容器，确保整个按钮区域都可点击
            anchors.fill: parent
            // 必须开启悬停检测，否则containsMouse属性不会更新
            hoverEnabled: true
            // 鼠标悬停时显示手型光标，提示可点击
            cursorShape: Qt.PointingHandCursor
            // 点击事件：触发根元素的closeClicked信号
            onClicked: root.closeClicked()
        }
    }

    // ================================================================
    // 2. 最小化按钮（黄色）- macOS窗口控制中间按钮
    // ================================================================
    Item {
        width: 16
        height: 16

        // 圆形背景层
        Rectangle {
            id: minBg
            anchors.fill: parent
            radius: width / 2
            // macOS最小化按钮标准黄色 (#F2CA44)
            color: "#F2CA44"
        }

        // 最小化符号层（─）
        Text {
            anchors.centerIn: parent
            // 最小化符号（使用长横线，比短横线更美观）
            text: "─"
            // 符号颜色（深黄色，与黄色背景形成对比）
            color: "#8F591D"
            font.pixelSize: 12
            font.bold: true
            // 透明度：鼠标悬停时显示
            opacity: minMouse.containsMouse ? 1 : 0
            // 透明度变化动画
            Behavior on opacity { 
                NumberAnimation { 
                    duration: 100 
                } 
            }
        }

        // 鼠标交互区域
        MouseArea {
            id: minMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            // 点击事件：触发根元素的minimizeClicked信号
            onClicked: root.minimizeClicked()
        }
    }

    // ================================================================
    // 3. 最大化按钮（绿色）- macOS窗口控制最右侧按钮
    // ================================================================
    Item {
        width: 16
        height: 16

        // 圆形背景层
        Rectangle {
            id: maxBg
            anchors.fill: parent
            radius: width / 2
            // macOS最大化按钮标准绿色 (#65C466)
            color: "#65C466"
        }

        // 最大化符号层（口）
        Text {
            anchors.centerIn: parent
            // 最大化符号（使用方形，直观表示窗口最大化）
            text: "口"
            // 符号颜色（深绿色，与绿色背景形成对比）
            color: "#286017"
            font.pixelSize: 12
            font.bold: true
            // 透明度：鼠标悬停时显示
            opacity: maxMouse.containsMouse ? 1 : 0
            // 透明度变化动画
            Behavior on opacity { 
                NumberAnimation { 
                    duration: 100 
                } 
            }
        }

        // 鼠标交互区域
        MouseArea {
            id: maxMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            // 点击事件：触发根元素的maximizeClicked信号
            onClicked: root.maximizeClicked()
        }
    }
}