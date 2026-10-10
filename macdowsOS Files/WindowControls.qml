import QtQuick 6.5

Row {
    id: root
    property bool windowActive: true
    readonly property bool hovered: closeMouse.containsMouse || minimizeMouse.containsMouse || maximizeMouse.containsMouse
    signal minimizeClicked()
    signal maximizeClicked()
    signal closeClicked()
    spacing: 11
    height: 16

    component TrafficLight: Rectangle {
        property color activeColor
        property string symbol
        width: 16
        height: 16
        radius: 8
        color: root.windowActive || root.hovered ? activeColor : "#585858"
        border.color: Qt.darker(color, 1.18)
        LineIcon {
            anchors.centerIn: parent
            width: 10
            height: 10
            name: parent.symbol
            color: "#90000000"
            strokeWidth: 1.2
            opacity: root.hovered ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 100 } }
        }
    }
    TrafficLight {
        activeColor: "#ff5f57"
        symbol: "close"
        MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.closeClicked() }
    }
    TrafficLight {
        activeColor: "#febc2e"
        symbol: "minus"
        MouseArea { id: minimizeMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.minimizeClicked() }
    }
    TrafficLight {
        activeColor: "#28c840"
        symbol: "expand"
        MouseArea { id: maximizeMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.maximizeClicked() }
    }
}
