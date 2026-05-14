// SidebarList.qml
import QtQuick 6.5
import QtQuick.Controls 6.5

ListView {
    id: sidebarListView

    // 暴露属性：允许父组件设置数据模型（例如 ListModel）
    property alias sidebarModel: sidebarListView.model

    // 信号：点击某项时发出，传递路径
    signal itemClicked(string path)

    clip: true
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    // 自定义委托样式
    delegate: ItemDelegate {
        id: delegateItem
        width: sidebarListView.width
        height: 38

        // 背景：悬停时显示暗色
        background: Rectangle {
            color: delegateItem.hovered ? "#2A2D30" : "transparent"
            radius: 6
        }

        // 内容行（图标 + 文本）
        contentItem: Row {
            anchors.fill: parent
            anchors.leftMargin: 12
            spacing: 10

            // 快捷方式图标（可替换为 Image）
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "📂"              // 默认文件夹图标
                font.pixelSize: 18
                color: "#F2CA44"
            }

            // 文本标签
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: model.name
                color: "#ECF0F1"
                font.pixelSize: 14
                elide: Text.ElideRight
                width: parent.width - 60   // 防止溢出
            }
        }

        // 点击时发出信号
        onClicked: sidebarListView.itemClicked(model.path)
    }
}