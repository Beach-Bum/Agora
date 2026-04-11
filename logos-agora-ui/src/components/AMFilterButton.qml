// AMFilterButton.qml — WeeChat TUI style filter toggle
import QtQuick 2.15

Rectangle {
    id: root
    property string text:   ""
    property bool   active: false
    signal clicked()

    implicitWidth:  label.implicitWidth + 12
    implicitHeight: 20
    radius: 0

    color:        active ? DSTheme.activeBg : mouse.containsMouse ? DSTheme.statusBg : "transparent"
    border.color: active ? DSTheme.blue : DSTheme.border
    border.width: 1

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.family: "Menlo"
        font.pixelSize: 11
        color: root.active ? DSTheme.yellow : mouse.containsMouse ? DSTheme.fg : DSTheme.dimFg
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
