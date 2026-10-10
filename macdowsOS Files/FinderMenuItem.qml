import QtQuick 6.5
import QtQuick.Controls 6.5

MenuItem {
    id: root
    implicitHeight: 30
    leftPadding: checkable ? 28 : 12
    rightPadding: 12
    contentItem: Text {
        text: root.text
        color: root.enabled ? "#eeeeee" : "#808080"
        font.pixelSize: 13
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    indicator: Text {
        x: 9
        anchors.verticalCenter: parent.verticalCenter
        text: root.checked ? "✓" : ""
        color: "#eeeeee"
        font.pixelSize: 13
    }
    background: Rectangle { radius: 6; color: root.highlighted ? "#0865d5" : "transparent" }
}
