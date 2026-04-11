// AMFilterButton.qml
import QtQuick 2.15

Rectangle {
    id: root
    property string text:   ""
    property bool   active: false
    signal clicked()

    implicitWidth:  label.implicitWidth + 24
    implicitHeight: 28
    radius: 6

    color:        active ? "rgba(124,106,247,0.15)" : mouse.containsMouse ? "#232739" : "transparent"
    border.color: active ? "#7c6af7" : "#2f3550"
    border.width: 1

    Behavior on color { ColorAnimation { duration: 80 } }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.pixelSize: 11
        font.weight: Font.Medium
        color: root.active ? "#9b8eff" : mouse.containsMouse ? "#c0c4d6" : "#8b91a8"
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
