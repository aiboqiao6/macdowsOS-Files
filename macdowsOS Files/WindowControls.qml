// WindowControls.qml
import QtQuick 6.5

Row {
    id: root
    spacing: 10

    signal minimizeClicked()
    signal maximizeClicked()
    signal closeClicked()

    // ========================
    // 1. 关闭按钮（红色）
    // ========================
    Item {
        width: 16
        height: 16

        // 圆形背景
        Rectangle {
            id: closeBg
            anchors.fill: parent
            radius: width / 2
            color: "#E66562"
        }

        // 符号，平时透明，悬停可见
        Text {
            anchors.centerIn: parent
            text: "✕"
            color: "#921E15"
            font.pixelSize: 12
            font.bold: true
            opacity: closeMouse.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 100 } }
        }

        // 鼠标交互
        MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true          // 必须开启，才能检测悬停
            cursorShape: Qt.PointingHandCursor
            onClicked: root.closeClicked()
        }
    }

    // ========================
    // 2. 最小化按钮（绿色）
    // ========================
    Item {
        width: 16
        height: 16

        Rectangle {
            id: minBg
            anchors.fill: parent
            radius: width / 2
            
            color: "#F2CA44"
        }

        Text {
            anchors.centerIn: parent
            text: "─"
            color: "#8F591D"
            font.pixelSize: 12
            font.bold: true
            opacity: minMouse.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 100 } }
        }

        MouseArea {
            id: minMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.minimizeClicked()
        }
    }

    // ========================
    // 3. 最大化按钮（黄色）
    // ========================
    Item {
        width: 16
        height: 16

        Rectangle {
            id: maxBg
            anchors.fill: parent
            radius: width / 2
            color: "#65C466"
        }

        Text {
            anchors.centerIn: parent
            text: "口"
            color: "#286017"
            font.pixelSize: 12
            font.bold: true
            opacity: maxMouse.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 100 } }
        }

        MouseArea {
            id: maxMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.maximizeClicked()
        }
    }
}