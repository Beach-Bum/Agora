// AMCard.qml — WeeChat TUI style card (box-drawing border)
import QtQuick 2.15

Rectangle {
    default property alias content: inner.data
    property string title: ""

    color:        DSTheme.bg
    border.color: DSTheme.border
    border.width: 1
    radius:       0

    Column {
        id: inner
        anchors { fill: parent; margins: 8 }
        spacing: 4
    }
}
