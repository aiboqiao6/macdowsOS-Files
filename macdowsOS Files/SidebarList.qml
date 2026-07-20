// SidebarList.qml
import QtQuick 6.5
import QtQuick.Controls 6.5

/* Sidebar view: C++ supplies roles; this component renders sections and rows. */
ListView {
    id: sidebarListView

    // 暴露属性：允许父组件设置数据模型（例如 ListModel）
    // Expose the ListView model with a descriptive property for parent QML.
    property alias sidebarModel: sidebarListView.model
    property string currentPath: ""
    // Bundled theme assets are preferred; LineIcon is the failure-safe fallback.
    property var iconSources: ({
        home: "qrc:/icons/home.png",
        desktop: "qrc:/icons/desktop.png",
        document: "qrc:/icons/documents.png",
        download: "qrc:/icons/downloads.png",
        picture: "qrc:/icons/pictures.png",
        music: "qrc:/icons/music.png",
        video: "qrc:/icons/videos.png",
        drive: "qrc:/icons/drive.png",
        folder: "qrc:/icons/folder.png"
    })

    function iconSource(icon) {
        return iconSources[icon] || iconSources.folder
    }

    // Keep section labels stable even when a stale translation or old model
    // value reaches QML. The two sidebar groups are intentionally fixed.
    function localizedSectionTitle(value) {
        var text = String(value).toLowerCase()
        if (text.indexOf("location") >= 0 || text.indexOf("position") >= 0 || text.indexOf("浣") >= 0)
            return "\u4F4D\u7F6E"
        return "\u4E2A\u4EBA\u6536\u85CF"
    }

    // 信号：点击某项时发出，传递路径
    signal itemClicked(string path)

    clip: true
    spacing: 2
    section.property: "section"
    section.criteria: ViewSection.FullString
    // Section headers are generated from the model's `section` role.
    section.delegate: Text {
        width: sidebarListView.width - 16
        height: 27
        leftPadding: 12
        topPadding: 7
        text: sidebarListView.localizedSectionTitle(section)
        color: "#7d879c"
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.letterSpacing: 0.6
    }
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    // Each row is a navigation target; clicking emits its normalized URL.
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

            // Prefer imported line icons with a vector fallback.
            Item {
                width: 20
                height: 20
                anchors.verticalCenter: parent.verticalCenter
                Image {
                    id: sidebarAsset
                    anchors.fill: parent
                    source: sidebarListView.iconSource(model.icon)
                    sourceSize.width: 24
                    sourceSize.height: 24
                    fillMode: Image.PreserveAspectFit
                    opacity: delegateItem.highlighted ? 1 : 0.9
                }
                LineIcon {
                    anchors.fill: parent
                    name: model.icon === "drive" ? "drive" : model.icon === "home" ? "home" : "folder"
                    color: model.icon === "drive" ? "#8bc7ff" : "#d4e1fb"
                    visible: sidebarAsset.status !== Image.Ready
                }
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
