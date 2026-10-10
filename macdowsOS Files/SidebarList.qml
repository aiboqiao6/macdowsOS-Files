import QtQuick 6.5
import QtQuick.Controls 6.5

ListView {
    id: root
    property alias sidebarModel: root.model
    property string currentPath: ""
    property FinderTheme theme: FinderTheme {}
    signal itemClicked(string path)
    clip: true
    spacing: 1
    boundsBehavior: Flickable.StopAtBounds
    section.property: "section"
    section.criteria: ViewSection.FullString
    section.delegate: Item {
        required property string section
        width: root.width
        height: section.length ? 39 : 0
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 9
            text: section
            color: root.theme.mutedText
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
    }
    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
        width: 6
        contentItem: Rectangle { radius: 3; color: "#666666"; opacity: parent.active ? 0.8 : 0 }
    }
    delegate: ItemDelegate {
        id: entry
        required property string name
        required property string path
        required property var model
        readonly property string locationIcon: model.icon
        width: root.width
        height: root.theme.sidebarRowHeight
        highlighted: path === root.currentPath
        padding: 0
        background: Rectangle {
            radius: 9
            color: entry.highlighted ? "#454545" : entry.hovered ? "#343434" : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }
        }
        contentItem: Item {
            LineIcon {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 25
                height: 25
                name: entry.locationIcon
                color: entry.locationIcon === "drive" ? "#ababaf" : root.theme.accent
                strokeWidth: 1.7
            }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 45
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: entry.name
                color: root.theme.text
                font.pixelSize: 15
                font.weight: entry.highlighted ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
            }
        }
        onClicked: root.itemClicked(path)
    }
}
