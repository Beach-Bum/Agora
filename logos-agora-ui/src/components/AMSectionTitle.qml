// AMSectionTitle.qml
import QtQuick 2.15

Text {
    property bool small: false
    color: "#e8eaf0"
    font.pixelSize: small ? 13 : 17
    font.weight: Font.Bold
    font.letterSpacing: -0.4
}
