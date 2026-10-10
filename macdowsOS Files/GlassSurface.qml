import QtQuick 6.5

Rectangle {
    id: root
    property bool highlighted: false
    radius: height / 2
    gradient: Gradient {
        GradientStop { position: 0; color: root.highlighted ? "#515151" : "#383838" }
        GradientStop { position: 0.45; color: root.highlighted ? "#454545" : "#303030" }
        GradientStop { position: 1; color: root.highlighted ? "#414141" : "#2d2d2d" }
    }
    border.color: root.highlighted ? "#626262" : "#454545"
    border.width: 1
}
