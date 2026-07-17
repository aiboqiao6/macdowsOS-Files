// SidebarList.qml
import QtQuick 6.5
import QtQuick.Controls 6.5

ListView {
    id: sidebarListView

    // 暴露属性：允许父组件设置数据模型（例如 ListModel）
    property alias sidebarModel: sidebarListView.model
    property string currentPath: ""

    // 信号：点击某项时发出，传递路径
    signal itemClicked(string path)

    clip: true
    spacing: 2
    section.property: "section"
    section.criteria: ViewSection.FullString
    section.delegate: Text {
        width: sidebarListView.width - 16
        height: 27
        leftPadding: 12
        topPadding: 7
        text: section
        color: "#7d879c"
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.letterSpacing: 0.6
    }
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    // 自定义委托样式
    delegate: ItemDelegate {
        id: delegateItem
        width: sidebarListView.width
        height: 36

        // 背景：悬停时显示暗色
        background: Rectangle {
            color: delegateItem.highlighted ? "#30466d" : delegateItem.hovered ? "#252d3e" : "transparent"
            radius: 8
            border.color: delegateItem.highlighted ? "#4c6da5" : "transparent"
            border.width: 1
        }

        // 内容行（图标 + 文本）
        contentItem: Row {
            anchors.fill: parent
            anchors.leftMargin: 12
            spacing: 10

            // 快捷方式图标（可替换为 Image）
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ({home:"\uE80F", desktop:"\uE716", document:"\uE8A5", download:"\uE896", picture:"\uE91B", music:"\uE8D6", video:"\uE714", drive:"\uEDA2"})[model.icon] || "\uE8B7"
                font.family: "Segoe Fluent Icons"
                font.pixelSize: 16
                color: model.icon === "drive" ? "#8bc7ff" : "#d4e1fb"
            }

            // 文本标签
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: model.name
                color: delegateItem.highlighted ? "#f3f7ff" : "#c9d0df"
                font.pixelSize: 13
                elide: Text.ElideRight
                width: parent.width - 60   // 防止溢出
            }
        }

        highlighted: model.path === sidebarListView.currentPath
        onClicked: {
            sidebarListView.currentPath = model.path
            sidebarListView.itemClicked(model.path)
        }
    }
}
