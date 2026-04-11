// AMTag.qml
import QtQuick 2.15

Rectangle {
    property string text: ""

    implicitWidth:  label.implicitWidth + 16
    implicitHeight: 20
    radius: 10
    color: "#232739"

    Text {
        id: label
        anchors.centerIn: parent
        text: parent.text
        color: "#8b91a8"
        font.pixelSize: 10
        font.weight: Font.Medium
    }
}
