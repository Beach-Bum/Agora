// AMStatusBadge.qml — WeeChat TUI style status line
import QtQuick 2.15
import QtQuick.Layouts 1.15

Rectangle {
    property string text:    ""
    property string variant: "info"   // info | success | warning | error

    implicitWidth:  row.implicitWidth + 16
    implicitHeight: 20
    radius: 0

    color: "transparent"
    border.color: {
        switch (variant) {
        case "success": return DSTheme.cyan
        case "warning": return DSTheme.yellow
        case "error":   return DSTheme.red
        default:        return DSTheme.blue
        }
    }
    border.width: 1

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: {
                switch (parent.parent.variant) {
                case "success": return "✓"
                case "warning": return "!"
                case "error":   return "✗"
                default:        return "·"
                }
            }
            font.family: "Menlo"
            font.pixelSize: 12
            font.bold: true
            color: {
                switch (parent.parent.variant) {
                case "success": return DSTheme.cyan
                case "warning": return DSTheme.yellow
                case "error":   return DSTheme.red
                default:        return DSTheme.blue
                }
            }
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: row.parent.text
            font.family: "Menlo"
            font.pixelSize: 11
            color: DSTheme.fg
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
