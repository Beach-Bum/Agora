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

    color:        active ? LogosTheme.activeBg : mouse.containsMouse ? LogosTheme.statusBg : "transparent"
    border.color: active ? LogosTheme.blue : LogosTheme.border
    border.width: 1

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.family: "Menlo"
        font.pixelSize: 11
        color: root.active ? LogosTheme.yellow : mouse.containsMouse ? LogosTheme.fg : LogosTheme.dimFg
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
