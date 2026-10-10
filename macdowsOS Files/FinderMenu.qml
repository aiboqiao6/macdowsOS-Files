import QtQuick 6.5
import QtQuick.Controls 6.5

Menu {
    implicitWidth: 236
    padding: 6
    background: Rectangle { color: "#f0353535"; radius: 12; border.color: "#606060" }
    delegate: FinderMenuItem {}
}
