// AMStatusBadge.qml
import QtQuick 2.15
import QtQuick.Layouts 1.15

Rectangle {
    property string text:    ""
    property string variant: "info"   // info | success | warning | error

    implicitWidth:  row.implicitWidth + 20
    implicitHeight: 34
    radius: 6

    color: {
        switch (variant) {
        case "success": return "rgba(47,182,122,0.1)"
        case "warning": return "rgba(245,159,0,0.1)"
        case "error":   return "rgba(224,82,82,0.1)"
        default:        return "rgba(124,106,247,0.1)"
        }
    }
    border.color: {
        switch (variant) {
        case "success": return "rgba(47,182,122,0.25)"
        case "warning": return "rgba(245,159,0,0.25)"
        case "error":   return "rgba(224,82,82,0.25)"
        default:        return "rgba(124,106,247,0.3)"
        }
    }
    border.width: 1

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Rectangle {
            width: 6; height: 6; radius: 3
            anchors.verticalCenter: parent.verticalCenter
            color: {
                switch (parent.parent.variant) {
                case "success": return "#2fb67a"
                case "warning": return "#f59f00"
                case "error":   return "#e05252"
                default:        return "#7c6af7"
                }
            }
        }

        Text {
            text:           row.parent.parent.text
            font.pixelSize: 12
            color: {
                switch (row.parent.parent.variant) {
                case "success": return "#2fb67a"
                case "warning": return "#f59f00"
                case "error":   return "#e05252"
                default:        return "#9b8eff"
                }
            }
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
