// AMButton.qml — WeeChat TUI style button
import QtQuick 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root

    property string text: ""
    property bool   primary: false
    property bool   danger:  false
    property bool   enabled: true

    signal clicked()

    implicitWidth:  label.implicitWidth + 20
    implicitHeight: 22
    radius: 0
    opacity: root.enabled ? 1.0 : 0.4

    color: {
        if (!root.enabled)       return "transparent"
        if (mouse.pressed)       return DSTheme.activeBg
        if (mouse.containsMouse) return DSTheme.statusBg
        return "transparent"
    }

    border.color: primary ? DSTheme.blue : danger ? DSTheme.red : DSTheme.border
    border.width: 1

    Text {
        id: label
        anchors.centerIn: parent
        text: "[" + root.text + "]"
        color: root.primary ? DSTheme.blue : root.danger ? DSTheme.red : DSTheme.fg
        font.family: "Menlo"
        font.pixelSize: 12
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
