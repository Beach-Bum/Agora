// WalletView.qml
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Item {
    id: root

    // ── Public API ────────────────────────────────────────────────
    function setState(s) {
        // Properties come from agora Q_PROPERTY bindings directly
        // This is called when walletState() signal fires for extra data
        if (s.txHash)       txHashText.text  = s.txHash.slice(0,30)+"…"
        if (s.block)        blockText.text   = "#" + parseInt(s.block).toLocaleString()
    }

    function setHistory(trades) {
        txModel.clear()
        for (var i = 0; i < trades.length; ++i) {
            txModel.append(trades[i])
        }
    }

    property string txHashValue: "—"
    property string blockValue:  "—"

    Component.onCompleted: {
        agora.getWalletState()
        agora.getTradeHistory()
    }

    ListModel { id: txModel }

    // ── Layout ────────────────────────────────────────────────────
    ScrollView {
        anchors.fill: parent
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: parent.width
            anchors { topMargin: 20; leftMargin: 20; rightMargin: 20 }
            spacing: 14

            AMSectionTitle { text: "Agent Wallet" }
            Text {
                text: "Identity on Logos Blockchain LSSA · Private NOM transfers via Blend Network"
                color: "#8b91a8"; font.pixelSize: 12
                wrapMode: Text.WordWrap; Layout.fillWidth: true
            }

            // Balance stats
            RowLayout {
                spacing: 10; Layout.fillWidth: true
                Repeater {
                    model: [
                        { lbl: "NOM Balance", expr: "balance",    clr: "#7c6af7" },
                        { lbl: "NOM Staked",  expr: "stake",      clr: "#2fb67a" },
                        { lbl: "Reputation",  expr: "reputation", clr: "#f59f00" },
                    ]
                    delegate: Rectangle {
                        Layout.fillWidth: true; height: 72
                        color: "#141720"; border.color: "#252a3d"; border.width: 1; radius: 10
                        Column {
                            anchors.centerIn: parent; spacing: 4
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: {
                                    if (modelData.expr === "balance")    return agora.balance    || "—"
                                    if (modelData.expr === "stake")      return agora.stake      || "—"
                                    if (modelData.expr === "reputation") return agora.reputation > 0 ? (agora.reputation*100).toFixed(1)+"%" : "—"
                                    return "—"
                                }
                                color:          modelData.clr
                                font.pixelSize: 22
                                font.weight:    Font.Bold
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text:           modelData.lbl
                                color:          "#8b91a8"
                                font.pixelSize: 10
                            }
                        }
                    }
                }
            }

            // Identity card
            Rectangle {
                Layout.fillWidth: true; height: idCol.implicitHeight + 24
                color: "#141720"; border.color: "#252a3d"; border.width: 1; radius: 10
                ColumnLayout {
                    id: idCol
                    anchors { fill: parent; margins: 16 }
                    spacing: 10
                    Text { text: "Identity"; color: "#e8eaf0"; font.pixelSize: 12; font.weight: Font.Bold; font.letterSpacing: 0.8; opacity: 0.6 }
                    Repeater {
                        model: [
                            { lbl: "Agent ID",        valRef: "agentId"  },
                            { lbl: "Identity NFT Tx", valRef: "txHash"   },
                            { lbl: "Registered Block",valRef: "block"    },
                            { lbl: "Key Storage",     valRef: "keystore" },
                            { lbl: "Network Privacy", valRef: "privacy"  },
                        ]
                        delegate: RowLayout {
                            Layout.fillWidth: true; spacing: 10
                            Text { text: modelData.lbl; color: "#8b91a8"; font.pixelSize: 11; Layout.minimumWidth: 130 }
                            Text {
                                id: {
                                    if (modelData.valRef === "txHash") txHashText = this
                                    if (modelData.valRef === "block")  blockText  = this
                                    this
                                }
                                text: {
                                    switch (modelData.valRef) {
                                    case "agentId":  return agora.agentId.length > 0 ? agora.agentId.slice(0,22)+"…" : "—"
                                    case "keystore": return "✓ OS Keychain"
                                    case "privacy":  return "✓ Blend Network routing"
                                    default:         return "—"
                                    }
                                }
                                color: {
                                    switch (modelData.valRef) {
                                    case "keystore":
                                    case "privacy": return "#2fb67a"
                                    case "agentId": return "#38b2ac"
                                    default:        return "#e8eaf0"
                                    }
                                }
                                font.pixelSize: 11
                                font.family:    modelData.valRef === "agentId" || modelData.valRef === "txHash" ? "Menlo, monospace" : ""
                                Layout.fillWidth: true; wrapMode: Text.WrapAnywhere
                            }
                        }
                    }
                }
                property alias txHashText: _tx
                property alias blockText:  _bl
                Text { id: _tx; visible: false }
                Text { id: _bl; visible: false }
            }

            // Trade history
            Rectangle {
                Layout.fillWidth: true; height: histCol.implicitHeight + 24
                color: "#141720"; border.color: "#252a3d"; border.width: 1; radius: 10
                ColumnLayout {
                    id: histCol
                    anchors { fill: parent; margins: 16 }
                    spacing: 0

                    Text { text: "Recent Transactions"; color: "#e8eaf0"; font.pixelSize: 12; font.weight: Font.Bold; font.letterSpacing: 0.8; opacity: 0.6; bottomPadding: 10 }

                    Text {
                        visible: txModel.count === 0
                        text:    "No trades yet"
                        color:   "#555d7a"; font.pixelSize: 12; padding: 8
                    }

                    Repeater {
                        model: txModel
                        delegate: RowLayout {
                            Layout.fillWidth: true; spacing: 10
                            Rectangle { width: 1; height: 40; color: "#252a3d"; visible: index > 0; Layout.alignment: Qt.AlignLeft }
                            Text { text: model.icon || "🤝"; font.pixelSize: 15; Layout.preferredWidth: 22 }
                            Column {
                                spacing: 3; Layout.fillWidth: true
                                Text { text: model.description || model.desc || "Trade"; color: "#e8eaf0"; font.pixelSize: 12 }
                                Text { text: model.escrowId ? model.escrowId.slice(0,24)+"…" : ""; color: "#555d7a"; font.pixelSize: 10; font.family: "Menlo, monospace"; visible: model.escrowId !== undefined }
                            }
                            Column {
                                spacing: 3; horizontalItemAlignment: Column.AlignRight
                                Text {
                                    text:           model.amount || "—"
                                    color:          (model.amount || "").startsWith("+") ? "#2fb67a" : "#e05252"
                                    font.pixelSize: 12; font.weight: Font.SemiBold
                                    horizontalAlignment: Text.AlignRight
                                }
                                Text {
                                    text:           model.timeAgo || agora.fmtAgo(model.timestamp || 0)
                                    color:          "#555d7a"; font.pixelSize: 10
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
                    }
                }
            }

            AMButton { text: "Refresh"; onClicked: { agora.getWalletState(); agora.getTradeHistory() } }
            Item { height: 20 }
        }
    }
}
