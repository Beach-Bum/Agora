// AMHashRow.qml
import QtQuick 2.15
import QtQuick.Layouts 1.15

Rectangle {
    property string label: ""
    property string value: ""

    implicitHeight: 36
    color: "#1c1f2e"
    radius: 6

    RowLayout {
        anchors { fill: parent; margins: 10 }
        spacing: 10

        Text {
            text:           parent.parent.label
            color:          "#8b91a8"
            font.pixelSize: 11
            Layout.minimumWidth: 120
        }

        Text {
            text:            parent.parent.value
            color:           "#38b2ac"
            font.pixelSize:  10
            font.family:     "Menlo, monospace"
            wrapMode:        Text.WrapAnywhere
            Layout.fillWidth: true
            elide:           Text.ElideMiddle
        }

        Text {
            text:           "Copy"
            color:          copyMouse.containsMouse ? "#7c6af7" : "#555d7a"
            font.pixelSize: 10
            Behavior on color { ColorAnimation { duration: 80 } }
            MouseArea {
                id: copyMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape:  Qt.PointingHandCursor
                onClicked: {
                    // agora is the QML context property from AgoraBridge
                    if (typeof agora !== "undefined")
                        agora.copyToClipboard(parent.parent.parent.parent.value)
                }
            }
        }
    }
}
