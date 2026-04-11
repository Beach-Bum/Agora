// WalletView.qml — WeeChat TUI style
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Item {
    id: root

    function setState(s) {
        if (s.txHash) txHashText.text = s.txHash.slice(0,30) + "…"
        if (s.block)  blockText.text  = "#" + parseInt(s.block).toLocaleString()
    }
    function setHistory(trades) { txModel.clear(); for (var i = 0; i < trades.length; ++i) txModel.append(trades[i]) }

    Component.onCompleted: { agora.getWalletState(); agora.getTradeHistory() }
    ListModel { id: txModel }

    Rectangle {
        anchors.fill: parent; color: LogosTheme.bg

        ScrollView {
            anchors.fill: parent
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: parent.width; anchors.topMargin: 8; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6

                AMSectionTitle { text: "Agent Wallet" }
                Text { text: "Identity on Logos Blockchain LSSA · Private NOM transfers via Blend Network"; color: LogosTheme.dimFg; font.family: "Menlo"; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true }

                // Balance stats
                Row {
                    spacing: 24; Layout.fillWidth: true
                    Repeater {
                        model: [
                            { lbl: "NOM Balance", expr: "balance", clr: LogosTheme.blue },
                            { lbl: "NOM Staked", expr: "stake", clr: LogosTheme.cyan },
                            { lbl: "Reputation", expr: "reputation", clr: LogosTheme.yellow },
                        ]
                        delegate: Column {
                            spacing: 2
                            Text {
                                text: {
                                    if (modelData.expr === "balance") return agora.balance || "—"
                                    if (modelData.expr === "stake") return agora.stake || "—"
                                    if (modelData.expr === "reputation") return agora.reputation > 0 ? (agora.reputation*100).toFixed(1)+"%" : "—"
                                    return "—"
                                }
                                color: modelData.clr; font.family: "Menlo"; font.pixelSize: 18; font.bold: true
                            }
                            Text { text: modelData.lbl; color: LogosTheme.dimFg; font.family: "Menlo"; font.pixelSize: 10 }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: LogosTheme.border }

                // Identity
                Text { text: "├─ Identity ─"; color: LogosTheme.border; font.family: "Menlo"; font.pixelSize: 11 }
                Repeater {
                    model: [
                        { lbl: "Agent ID",         valRef: "agentId" },
                        { lbl: "Identity NFT Tx",  valRef: "txHash" },
                        { lbl: "Registered Block", valRef: "block" },
                        { lbl: "Key Storage",      valRef: "keystore" },
                        { lbl: "Network Privacy",  valRef: "privacy" },
                    ]
                    delegate: Row {
                        spacing: 8; Layout.fillWidth: true
                        Text { text: modelData.lbl + ":"; color: LogosTheme.dimFg; font.family: "Menlo"; font.pixelSize: 11; width: 140 }
                        Text {
                            id: { if (modelData.valRef === "txHash") txHashText = this; if (modelData.valRef === "block") blockText = this; this }
                            text: {
                                switch (modelData.valRef) {
                                case "agentId": return agora.agentId.length > 0 ? agora.agentId.slice(0,22)+"…" : "—"
                                case "keystore": return "✓ OS Keychain"
                                case "privacy": return "✓ Blend Network routing"
                                default: return "—"
                                }
                            }
                            color: {
                                switch (modelData.valRef) {
                                case "keystore": case "privacy": return LogosTheme.cyan
                                case "agentId": return LogosTheme.cyan
                                default: return LogosTheme.fg
                                }
                            }
                            font.family: "Menlo"; font.pixelSize: 11; wrapMode: Text.WrapAnywhere
                        }
                    }
                }
                property alias txHashText: _tx; property alias blockText: _bl
                Text { id: _tx; visible: false }; Text { id: _bl; visible: false }

                Rectangle { Layout.fillWidth: true; height: 1; color: LogosTheme.border }

                // Trade history
                Text { text: "├─ Recent Transactions ─"; color: LogosTheme.border; font.family: "Menlo"; font.pixelSize: 11 }

                // Column header
                Rectangle {
                    Layout.fillWidth: true; height: 18; color: LogosTheme.statusBg
                    Row {
                        anchors.fill: parent; anchors.leftMargin: 6; spacing: 0
                        Text { text: " "; width: 24; color: LogosTheme.dimFg; font.family: "Menlo"; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "DESCRIPTION"; width: 300; color: LogosTheme.dimFg; font.family: "Menlo"; font.pixelSize: 10; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "AMOUNT"; width: 100; color: LogosTheme.dimFg; font.family: "Menlo"; font.pixelSize: 10; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "TIME"; color: LogosTheme.dimFg; font.family: "Menlo"; font.pixelSize: 10; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                    }
                }

                Text { visible: txModel.count === 0; text: "No trades yet"; color: LogosTheme.dimFg; font.family: "Menlo"; font.pixelSize: 12 }

                Repeater {
                    model: txModel
                    delegate: Rectangle {
                        Layout.fillWidth: true; height: 20; color: index % 2 === 0 ? LogosTheme.bg : LogosTheme.altBg
                        Row {
                            anchors.fill: parent; anchors.leftMargin: 6; spacing: 0
                            Text { text: model.icon || "·"; font.pixelSize: 13; width: 24; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: model.description || model.desc || "Trade"; color: LogosTheme.fg; font.family: "Menlo"; font.pixelSize: 11; width: 300; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight }
                            Text { text: model.amount || "—"; color: (model.amount || "").startsWith("+") ? LogosTheme.cyan : LogosTheme.red; font.family: "Menlo"; font.pixelSize: 11; font.bold: true; width: 100; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: model.timeAgo || agora.fmtAgo(model.timestamp || 0); color: LogosTheme.dimFg; font.family: "Menlo"; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }

                Item { height: 4 }
                AMButton { text: "Refresh"; onClicked: { agora.getWalletState(); agora.getTradeHistory() } }
                Item { height: 10 }
            }
        }
    }
}
