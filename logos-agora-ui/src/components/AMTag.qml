// AMTag.qml — WeeChat TUI style tag
import QtQuick 2.15

Rectangle {
    property string text: ""

    implicitWidth:  label.implicitWidth + 10
    implicitHeight: 18
    radius: 0
    color: "transparent"
    border.color: LogosTheme.border
    border.width: 1

    Text {
        id: label
        anchors.centerIn: parent
        text: parent.text
        color: LogosTheme.cyan
        font.family: "Menlo"
        font.pixelSize: 10
    }
}
