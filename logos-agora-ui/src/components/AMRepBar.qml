// AMRepBar.qml — WeeChat TUI style reputation bar using block characters
import QtQuick 2.15
import QtQuick.Layouts 1.15

RowLayout {
    property real   value:     0.0
    property string stakeText: ""

    spacing: 6

    Text {
        text: "rep:"
        color: LogosTheme.dimFg
        font.family: "Menlo"
        font.pixelSize: 11
    }

    Text {
        text: {
            var filled = Math.round(value * 20)
            var empty  = 20 - filled
            return "█".repeat(filled) + "░".repeat(empty)
        }
        color: value > 0.9 ? LogosTheme.cyan : value > 0.75 ? LogosTheme.yellow : LogosTheme.red
        font.family: "Menlo"
        font.pixelSize: 10
        Layout.fillWidth: true
    }

    Text {
        text: (value * 100).toFixed(1) + "%"
        font.family: "Menlo"
        font.pixelSize: 11
        font.bold: true
        color: value > 0.9 ? LogosTheme.cyan : value > 0.75 ? LogosTheme.yellow : LogosTheme.red
        Layout.minimumWidth: 42
        horizontalAlignment: Text.AlignRight
    }

    Text {
        text: stakeText
        font.family: "Menlo"
        font.pixelSize: 11
        color: LogosTheme.blue
        visible: stakeText !== ""
    }
}
