// AMButton.qml
import QtQuick 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root

    property string text: ""
    property bool   primary: false
    property bool   danger:  false
    property bool   enabled: true

    signal clicked()

    implicitWidth:  label.implicitWidth + 32
    implicitHeight: 36
    radius: 6
    opacity: root.enabled ? 1.0 : 0.4

    color: {
        if (!root.enabled)  return "transparent"
        if (mouse.pressed)  return primary ? "#6358e0" : danger ? "rgba(224,82,82,0.15)" : "#2a2f45"
        if (mouse.containsMouse) return primary ? "#8876ff" : danger ? "rgba(224,82,82,0.1)" : "#232739"
        return primary ? "#7c6af7" : "transparent"
    }

    border.color: {
        if (primary) return mouse.containsMouse ? "#8876ff" : "#7c6af7"
        if (danger)  return "#e05252"
        return mouse.containsMouse ? "#4a5272" : "#2f3550"
    }
    border.width: 1

    Behavior on color { ColorAnimation { duration: 80 } }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.primary ? "white" : root.danger ? "#e05252" : "#9096b0"
        font.pixelSize: 12
        font.weight: Font.Medium
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: root.enabled
        onClicked: root.clicked()
    }
}
