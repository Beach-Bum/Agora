// AMRepBar.qml
import QtQuick 2.15
import QtQuick.Layouts 1.15

RowLayout {
    property real  value:      0.0    // 0.0 – 1.0
    property string stakeText: ""

    spacing: 9

    Rectangle {
        Layout.fillWidth: true
        height: 4
        radius: 2
        color:  "#252a3d"

        Rectangle {
            width:  parent.width * Math.max(0, Math.min(1, value))
            height: 4
            radius: 2
            color:  value > 0.9 ? "#2fb67a" : value > 0.75 ? "#f59f00" : "#e05252"
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        }
    }

    Text {
        text:           (value * 100).toFixed(1) + "%"
        font.pixelSize: 11
        font.weight:    Font.SemiBold
        color:          value > 0.9 ? "#2fb67a" : value > 0.75 ? "#f59f00" : "#e05252"
        Layout.minimumWidth: 42
        horizontalAlignment: Text.AlignRight
    }

    Text {
        text:           stakeText
        font.pixelSize: 11
        color:          "#7c6af7"
        visible:        stakeText !== ""
    }
}
