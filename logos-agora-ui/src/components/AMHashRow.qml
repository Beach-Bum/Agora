// AMHashRow.qml — WeeChat TUI style hash/value row
import QtQuick 2.15
import QtQuick.Layouts 1.15

Rectangle {
    property string label: ""
    property string value: ""

    implicitHeight: 20
    color: "transparent"
    radius: 0

    RowLayout {
        anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
        spacing: 8

        Text {
            text: parent.parent.label + ":"
            color: DSTheme.dimFg
            font.family: "Menlo"
            font.pixelSize: 11
            Layout.minimumWidth: 120
        }

        Text {
            text: parent.parent.value
            color: DSTheme.cyan
            font.family: "Menlo"
            font.pixelSize: 11
            wrapMode: Text.WrapAnywhere
            Layout.fillWidth: true
            elide: Text.ElideMiddle
        }

        Text {
            text: "[copy]"
            color: copyMouse.containsMouse ? DSTheme.blue : DSTheme.dimFg
            font.family: "Menlo"
            font.pixelSize: 10
            MouseArea {
                id: copyMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (typeof agora !== "undefined")
                        agora.copyToClipboard(parent.parent.parent.parent.value)
                }
            }
        }
    }
}
