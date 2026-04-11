// AMSectionTitle.qml — WeeChat TUI style section heading with box-drawing
import QtQuick 2.15
import QtQuick.Layouts 1.15

RowLayout {
    property string text: ""
    property bool small: false
    spacing: 0
    Layout.fillWidth: true

    Text {
        text: "├─ "
        color: DSTheme.border
        font.family: "Menlo"
        font.pixelSize: parent.small ? 12 : 13
    }
    Text {
        text: parent.text
        color: DSTheme.fg
        font.family: "Menlo"
        font.pixelSize: parent.small ? 12 : 13
        font.bold: true
    }
    Text {
        text: " ─"
        color: DSTheme.border
        font.family: "Menlo"
        font.pixelSize: parent.small ? 12 : 13
        Layout.fillWidth: true
    }
}
