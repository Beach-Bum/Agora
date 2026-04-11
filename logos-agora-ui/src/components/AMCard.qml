// AMCard.qml
import QtQuick 2.15

Rectangle {
    default property alias content: inner.data
    property string title: ""

    color:        "#141720"
    border.color: "#252a3d"
    border.width: 1
    radius:       10

    Column {
        id: inner
        anchors { fill: parent; margins: 16 }
        spacing: 12
    }
}
