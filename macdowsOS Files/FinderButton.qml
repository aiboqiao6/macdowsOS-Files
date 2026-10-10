import QtQuick 6.5
import QtQuick.Controls 6.5

AbstractButton {
    id: root
    property string iconName: ""
    property string tooltip: ""
    property bool capsule: true
    property int iconSize: 22
    implicitWidth: 42
    implicitHeight: 42
    hoverEnabled: true
    opacity: enabled ? 1 : 0.35
    background: Item {
        GlassSurface {
            anchors.fill: parent
            visible: root.capsule
            highlighted: root.checked || root.down || root.hovered
        }
        Rectangle {
            anchors.fill: parent
            visible: !root.capsule && (root.hovered || root.checked || root.down)
            radius: height / 2
            color: root.checked || root.down ? "#515151" : "#3e3e3e"
        }
    }
    contentItem: Item {
        LineIcon { anchors.centerIn: parent; width: root.iconSize; height: root.iconSize; name: root.iconName; color: "#e5e5e5" }
    }
    ToolTip.visible: hovered && tooltip.length > 0
    ToolTip.delay: 650
    ToolTip.text: tooltip
    Accessible.name: tooltip
}
