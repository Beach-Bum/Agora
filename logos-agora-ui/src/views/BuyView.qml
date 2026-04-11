// BuyView.qml
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Item {
    id: root

    // ── State machine ─────────────────────────────────────────────
    // form → buying → complete | error
    property string state: "form"

    // ── Public API called by AgoraRoot ────────────────────────────
    function appendLog(msg, color) {
        logModel.append({ msg: msg, clr: color || "#555d7a" })
        logView.positionViewAtEnd()
    }

    function onOffersReceived(offers) {
        appendLog("  " + offers.length + " offers evaluated by daemon-ai", "#7c9ef7")
    }

    function onOfferAccepted(sessionId, escrowId) {
        appendLog("  Escrow locked: " + escrowId.slice(0,22) + "…", "#7c9ef7")
    }

    function onComplete(receipt) {
        receiptCid.value    = receipt.cid        || "—"
        receiptHash.value   = receipt.outputHash || "—"
        receiptEscrow.value = receipt.escrowId   || "—"
        outputText.text     = receipt.output     || ""
        root.state = "complete"
    }

    function onError(msg) {
        errorText.text = msg
        root.state = "error"
    }

    function reset() {
        logModel.clear()
        categoryBox.currentIndex = 0
        taskInput.text  = ""
        budgetField.text = "25"
        root.state = "form"
    }

    // ── Models ────────────────────────────────────────────────────
    ListModel { id: logModel }

    // ── View ──────────────────────────────────────────────────────
    StackLayout {
        anchors.fill: parent
        currentIndex: ["form","buying","complete","error"].indexOf(root.state)

        // ── FORM ──────────────────────────────────────────────────
        ScrollView {
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: parent.width
                anchors { topMargin: 20; leftMargin: 20; rightMargin: 20 }
                spacing: 14

                AMSectionTitle { text: "Buy a Service" }
                Text {
                    text: "daemon-ai picks the best offer · LSSA escrow locks funds · Blend Network private payment"
                    color: "#8b91a8"; font.pixelSize: 12
                    wrapMode: Text.WordWrap; Layout.fillWidth: true
                }

                // Category
                Rectangle {
                    Layout.fillWidth: true; height: 38
                    color: "#1c1f2e"; border.color: "#2f3550"; border.width: 1; radius: 6
                    Row {
                        anchors { fill: parent; margins: 1 }
                        Repeater {
                            id: categoryBox
                            property int currentIndex: 0
                            model: ["Inference","Research","Data","Code","Compute","Attestation"]
                            delegate: Rectangle {
                                width:  categoryBox.parent.width / categoryBox.count
                                height: categoryBox.parent.height
                                color:  categoryBox.currentIndex === index ? "rgba(124,106,247,0.2)" : "transparent"
                                radius: 5
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData; font.pixelSize: 11; font.weight: Font.Medium
                                    color: categoryBox.currentIndex === index ? "#9b8eff" : "#8b91a8"
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: categoryBox.currentIndex = index }
                            }
                        }
                    }
                }

                // Task input
                Rectangle {
                    Layout.fillWidth: true; height: 88
                    color: "#1c1f2e"; border.color: taskInput.activeFocus ? "#7c6af7" : "#2f3550"; border.width: 1; radius: 6
                    Behavior on border.color { ColorAnimation { duration: 100 } }
                    TextArea {
                        id: taskInput
                        anchors { fill: parent; margins: 10 }
                        placeholderText: "Describe the task…"
                        placeholderTextColor: "#555d7a"
                        background: null
                        color: "#e8eaf0"; font.pixelSize: 12
                        wrapMode: TextArea.Wrap
                    }
                }

                // Budget / price / rep row
                RowLayout {
                    spacing: 10; Layout.fillWidth: true
                    Repeater {
                        model: [
                            { lbl: "Budget (NOM)",    id: "budget",   val: "25"   },
                            { lbl: "Max Price/Token", id: "price",    val: "0.005" },
                            { lbl: "Min Reputation",  id: "minrep",   val: "0.70"  },
                        ]
                        delegate: ColumnLayout {
                            spacing: 5; Layout.fillWidth: true
                            Text { text: modelData.lbl; color: "#8b91a8"; font.pixelSize: 11 }
                            Rectangle {
                                Layout.fillWidth: true; height: 36
                                color: "#1c1f2e"; border.color: field.activeFocus ? "#7c6af7" : "#2f3550"
                                border.width: 1; radius: 6
                                Behavior on border.color { ColorAnimation { duration: 100 } }
                                TextInput {
                                    id: field
                                    anchors { fill: parent; margins: 10 }
                                    text: modelData.val
                                    color: "#e8eaf0"; font.pixelSize: 12
                                    horizontalAlignment: TextInput.AlignHCenter
                                    Component.onCompleted: {
                                        if (modelData.id === "budget") budgetField = field
                                    }
                                }
                            }
                        }
                    }
                }
                property alias budgetField: _budgetRef
                TextInput { id: _budgetRef; visible: false }

                AMButton {
                    text: "🔍  Find Agents & Buy"
                    primary: true
                    onClicked: {
                        root.state = "buying"
                        logModel.clear()
                        agora.broadcastIntent(
                            ["inference","research","data","code","compute","attestation"][categoryBox.currentIndex],
                            taskInput.text || "Default task",
                            budgetField.text || "25",
                            "0.005", 10000, 0.7
                        )
                    }
                }
            }
        }

        // ── BUYING ────────────────────────────────────────────────
        ColumnLayout {
            anchors { fill: parent; margins: 20 }
            spacing: 12

            AMSectionTitle { text: "Executing Purchase" }
            Text { text: "daemon-ai reasoning · Logos Messaging negotiation · LSSA escrow"; color: "#8b91a8"; font.pixelSize: 12 }

            // Terminal log
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                color: "#060810"; border.color: "#252a3d"; border.width: 1; radius: 8

                ListView {
                    id: logView
                    anchors { fill: parent; margins: 12 }
                    model: logModel
                    spacing: 0; clip: true

                    delegate: Text {
                        width:          logView.width
                        text:           model.msg
                        color:          model.clr
                        font.family:    "Menlo, monospace"
                        font.pixelSize: 11
                        lineHeight:     1.8
                        wrapMode:       Text.WrapAnywhere
                    }
                }
            }

            AMButton { text: "← Cancel"; onClicked: root.reset() }
        }

        // ── COMPLETE ──────────────────────────────────────────────
        ScrollView {
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: parent.width
                anchors { topMargin: 20; leftMargin: 20; rightMargin: 20 }
                spacing: 12

                AMStatusBadge { text: "Task complete · Escrow released · Reputation updated"; variant: "success"; Layout.fillWidth: true }

                // Output
                Rectangle {
                    Layout.fillWidth: true
                    height: outputCol.implicitHeight + 24
                    color: "#141720"; border.color: "#252a3d"; border.width: 1; radius: 10

                    ColumnLayout {
                        id: outputCol
                        anchors { fill: parent; margins: 16 }
                        spacing: 10

                        Text { text: "Task Output"; color: "#e8eaf0"; font.pixelSize: 12; font.weight: Font.Bold; font.letterSpacing: 0.8; opacity: 0.6 }

                        Text {
                            id: outputText
                            text: ""
                            color: "#e8eaf0"; font.pixelSize: 12; lineHeight: 1.7
                            wrapMode: Text.WordWrap; Layout.fillWidth: true
                        }
                    }
                }

                // Settlement
                Rectangle {
                    Layout.fillWidth: true
                    height: settleCol.implicitHeight + 24
                    color: "#141720"; border.color: "#252a3d"; border.width: 1; radius: 10

                    ColumnLayout {
                        id: settleCol
                        anchors { fill: parent; margins: 16 }
                        spacing: 8

                        Text { text: "Settlement Details"; color: "#e8eaf0"; font.pixelSize: 12; font.weight: Font.Bold; font.letterSpacing: 0.8; opacity: 0.6 }
                        AMHashRow { id: receiptCid;    label: "Logos Storage CID"; Layout.fillWidth: true }
                        AMHashRow { id: receiptHash;   label: "Output Hash";       Layout.fillWidth: true }
                        AMHashRow { id: receiptEscrow; label: "Escrow ID";         Layout.fillWidth: true }
                    }
                }

                AMButton { text: "Buy another service"; onClicked: root.reset() }
                Item { height: 20 }
            }
        }

        // ── ERROR ─────────────────────────────────────────────────
        ColumnLayout {
            anchors { fill: parent; margins: 20 }
            spacing: 12

            AMStatusBadge { id: errorText; text: "Error"; variant: "error"; Layout.fillWidth: true }
            AMButton { text: "← Try again"; onClicked: root.reset() }
        }
    }
}
