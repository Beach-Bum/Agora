// BuyView.qml — WeeChat TUI style
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Item {
    id: root
    property string state: "form"

    function appendLog(msg, color) {
        logModel.append({ msg: msg, clr: color || DSTheme.dimFg })
        logView.positionViewAtEnd()
    }
    function onOffersReceived(offers) { appendLog("  " + offers.length + " offers evaluated by daemon-ai", DSTheme.blue) }
    function onOfferAccepted(sessionId, escrowId) { appendLog("  Escrow locked: " + escrowId.slice(0,22) + "…", DSTheme.blue) }
    function onComplete(receipt) {
        receiptCid.value    = receipt.cid        || "—"
        receiptHash.value   = receipt.outputHash || "—"
        receiptEscrow.value = receipt.escrowId   || "—"
        outputText.text     = receipt.output     || ""
        root.state = "complete"
    }
    function onError(msg) { errorText.text = msg; root.state = "error" }
    function reset() { logModel.clear(); categoryBox.currentIndex = 0; taskInput.text = ""; budgetField.text = "25"; root.state = "form" }

    ListModel { id: logModel }

    Rectangle {
        anchors.fill: parent; color: DSTheme.bg

        StackLayout {
            anchors.fill: parent
            currentIndex: ["form","buying","complete","error"].indexOf(root.state)

            // FORM
            ScrollView {
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ColumnLayout {
                    width: parent.width; anchors.topMargin: 8; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6

                    AMSectionTitle { text: "Buy a Service" }
                    Text { text: "daemon-ai picks the best offer · LSSA escrow · Blend Network private payment"; color: DSTheme.dimFg; font.family: "Menlo"; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true }

                    // Category selector
                    Rectangle {
                        Layout.fillWidth: true; height: 22; color: "transparent"; border.color: DSTheme.border; border.width: 1
                        Row {
                            anchors.fill: parent; anchors.margins: 1
                            Repeater {
                                id: categoryBox; property int currentIndex: 0
                                model: ["Inference","Research","Data","Code","Compute","Attestation"]
                                delegate: Rectangle {
                                    width: categoryBox.parent.width / categoryBox.count; height: categoryBox.parent.height
                                    color: categoryBox.currentIndex === index ? DSTheme.activeBg : "transparent"
                                    Text { anchors.centerIn: parent; text: modelData; font.family: "Menlo"; font.pixelSize: 11; color: categoryBox.currentIndex === index ? DSTheme.yellow : DSTheme.dimFg }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: categoryBox.currentIndex = index }
                                }
                            }
                        }
                    }

                    // Task input
                    Rectangle {
                        Layout.fillWidth: true; height: 60; color: DSTheme.bg; border.color: taskInput.activeFocus ? DSTheme.blue : DSTheme.border; border.width: 1
                        TextArea {
                            id: taskInput; anchors.fill: parent; anchors.margins: 4
                            placeholderText: "Describe the task…"; placeholderTextColor: DSTheme.dimFg; background: null
                            color: DSTheme.fg; font.family: "Menlo"; font.pixelSize: 12; wrapMode: TextArea.Wrap
                        }
                    }

                    // Budget row
                    RowLayout {
                        spacing: 8; Layout.fillWidth: true
                        Repeater {
                            model: [
                                { lbl: "Budget (NOM)", id: "budget", val: "25" },
                                { lbl: "Max Price/Token", id: "price", val: "0.005" },
                                { lbl: "Min Reputation", id: "minrep", val: "0.70" },
                            ]
                            delegate: ColumnLayout {
                                spacing: 2; Layout.fillWidth: true
                                Text { text: modelData.lbl; color: DSTheme.dimFg; font.family: "Menlo"; font.pixelSize: 11 }
                                Rectangle {
                                    Layout.fillWidth: true; height: 22; color: DSTheme.bg; border.color: field.activeFocus ? DSTheme.blue : DSTheme.border; border.width: 1
                                    TextInput {
                                        id: field; anchors.fill: parent; anchors.margins: 4; text: modelData.val
                                        color: DSTheme.fg; font.family: "Menlo"; font.pixelSize: 12; horizontalAlignment: TextInput.AlignHCenter
                                        Component.onCompleted: { if (modelData.id === "budget") budgetField = field }
                                    }
                                }
                            }
                        }
                    }
                    property alias budgetField: _budgetRef
                    TextInput { id: _budgetRef; visible: false }

                    AMButton {
                        text: "Find Agents & Buy"; primary: true
                        onClicked: {
                            root.state = "buying"; logModel.clear()
                            agora.broadcastIntent(["inference","research","data","code","compute","attestation"][categoryBox.currentIndex], taskInput.text || "Default task", budgetField.text || "25", "0.005", 10000, 0.7)
                        }
                    }
                }
            }

            // BUYING — terminal log
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 8; spacing: 4
                AMSectionTitle { text: "Executing Purchase" }
                Text { text: "daemon-ai reasoning · Logos Messaging negotiation · LSSA escrow"; color: DSTheme.dimFg; font.family: "Menlo"; font.pixelSize: 11 }
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true; color: DSTheme.bg; border.color: DSTheme.border; border.width: 1
                    ListView {
                        id: logView; anchors.fill: parent; anchors.margins: 6; model: logModel; spacing: 0; clip: true
                        delegate: Text { width: logView.width; text: model.msg; color: model.clr; font.family: "Menlo"; font.pixelSize: 11; lineHeight: 1.6; wrapMode: Text.WrapAnywhere }
                    }
                }
                AMButton { text: "Cancel"; onClicked: root.reset() }
            }

            // COMPLETE
            ScrollView {
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ColumnLayout {
                    width: parent.width; anchors.topMargin: 8; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                    AMStatusBadge { text: "Task complete · Escrow released · Reputation updated"; variant: "success"; Layout.fillWidth: true }
                    Rectangle {
                        Layout.fillWidth: true; height: outputCol.implicitHeight + 16; color: DSTheme.bg; border.color: DSTheme.border; border.width: 1
                        ColumnLayout {
                            id: outputCol; anchors.fill: parent; anchors.margins: 8; spacing: 4
                            Text { text: "├─ Task Output ─"; color: DSTheme.border; font.family: "Menlo"; font.pixelSize: 11 }
                            Text { id: outputText; text: ""; color: DSTheme.fg; font.family: "Menlo"; font.pixelSize: 12; lineHeight: 1.5; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true; height: settleCol.implicitHeight + 16; color: DSTheme.bg; border.color: DSTheme.border; border.width: 1
                        ColumnLayout {
                            id: settleCol; anchors.fill: parent; anchors.margins: 8; spacing: 4
                            Text { text: "├─ Settlement Details ─"; color: DSTheme.border; font.family: "Menlo"; font.pixelSize: 11 }
                            AMHashRow { id: receiptCid; label: "Logos Storage CID"; Layout.fillWidth: true }
                            AMHashRow { id: receiptHash; label: "Output Hash"; Layout.fillWidth: true }
                            AMHashRow { id: receiptEscrow; label: "Escrow ID"; Layout.fillWidth: true }
                        }
                    }
                    AMButton { text: "Buy another service"; onClicked: root.reset() }
                    Item { height: 10 }
                }
            }

            // ERROR
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 8; spacing: 6
                AMStatusBadge { id: errorText; text: "Error"; variant: "error"; Layout.fillWidth: true }
                AMButton { text: "Try again"; onClicked: root.reset() }
            }
        }
    }
}
