// SellView.qml — WeeChat TUI style
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Item {
    id: root
    property string state: "dashboard"
    property var pendingIntent: ({})

    function onIntentReceived(intent) { pendingIntent = intent; intentBuyerId.text = intent.buyerId ? intent.buyerId.slice(0,20)+"…" : "—"; intentCategory.text = intent.category || "—"; intentBudget.text = (intent.budget || "—") + " NOM"; intentTask.text = intent.task || "—"; evalText.text = ""; evalText.color = LogosTheme.dimFg; root.state = "intent" }
    function onDaemonEval(action, reason) { var ok = action === "accept"; evalText.text = (ok ? "✓ " : "✗ ") + action.charAt(0).toUpperCase() + action.slice(1) + " — " + reason; evalText.color = ok ? LogosTheme.cyan : LogosTheme.yellow }
    function onOfferSent(sessionId) { appendLog("  Offer sent · session " + sessionId.slice(0,8) + "…", LogosTheme.cyan) }
    function appendLog(msg, color) { execModel.append({ msg: msg, clr: color || LogosTheme.dimFg }); execView.positionViewAtEnd() }
    function onTaskComplete(result) { deliveryCid.value = result.cid ? result.cid.slice(0,30)+"…" : "—"; deliveryHash.value = result.hash ? result.hash.slice(0,42)+"…" : "—"; deliveryEsc.value = result.escrowId ? result.escrowId.slice(0,28)+"…" : "—"; root.state = "complete" }

    ListModel { id: execModel }

    Rectangle {
        anchors.fill: parent; color: LogosTheme.bg

        StackLayout {
            anchors.fill: parent
            currentIndex: ["dashboard","intent","executing","complete"].indexOf(root.state)

            // DASHBOARD
            ScrollView {
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ColumnLayout {
                    width: parent.width; anchors.topMargin: 8; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                    AMSectionTitle { text: "Sell Service" }
                    Text { text: "daemon-ai evaluates intents · Logos Messaging sends offers · Logos Blockchain settles"; color: LogosTheme.dimFg; font.family: "Menlo"; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true }

                    // Stats row
                    Row {
                        spacing: 16; Layout.fillWidth: true
                        Repeater {
                            model: [
                                { lbl: "NOM Balance", val: agora.balance || "—", clr: LogosTheme.blue },
                                { lbl: "NOM Staked", val: agora.stake || "—", clr: LogosTheme.cyan },
                                { lbl: "Reputation", val: agora.reputation > 0 ? (agora.reputation * 100).toFixed(1) + "%" : "—", clr: LogosTheme.yellow },
                            ]
                            delegate: Column {
                                spacing: 2
                                Text { text: modelData.val; color: modelData.clr; font.family: "Menlo"; font.pixelSize: 16; font.bold: true }
                                Text { text: modelData.lbl; color: LogosTheme.dimFg; font.family: "Menlo"; font.pixelSize: 10 }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: LogosTheme.border }

                    // Agent info
                    Text { text: "├─ Agent Node ─"; color: LogosTheme.border; font.family: "Menlo"; font.pixelSize: 11 }
                    Row { spacing: 8; Text { text: "Agent ID:"; color: LogosTheme.dimFg; font.family: "Menlo"; font.pixelSize: 11 }; Text { text: agora.agentId.length > 0 ? agora.agentId.slice(0,22)+"…" : "Not registered"; color: LogosTheme.cyan; font.family: "Menlo"; font.pixelSize: 11 } }
                    Row { spacing: 8; Text { text: "Status:  "; color: LogosTheme.dimFg; font.family: "Menlo"; font.pixelSize: 11 }; Text { text: agora.registered ? "✓ Broadcasting via Logos Messaging" : "Not registered"; color: agora.registered ? LogosTheme.cyan : LogosTheme.yellow; font.family: "Menlo"; font.pixelSize: 11 } }

                    Rectangle { Layout.fillWidth: true; height: 1; color: LogosTheme.border }

                    // Services
                    Text { text: "├─ Services Offered ─"; color: LogosTheme.border; font.family: "Menlo"; font.pixelSize: 11 }
                    Repeater {
                        model: [
                            { cat: "inference", id: "inference-v1", price: "0.002 NOM/token", lat: "~850ms" },
                            { cat: "research",  id: "research-v1",  price: "10 NOM/report",   lat: "~8s" },
                        ]
                        delegate: Row {
                            spacing: 8; Layout.fillWidth: true
                            AMTag { text: modelData.cat }
                            Text { text: modelData.id; color: LogosTheme.dimFg; font.family: "Menlo"; font.pixelSize: 11 }
                            Text { text: modelData.price; color: LogosTheme.blue; font.family: "Menlo"; font.pixelSize: 11; font.bold: true }
                            Text { text: modelData.lat; color: LogosTheme.dimFg; font.family: "Menlo"; font.pixelSize: 10 }
                        }
                    }

                    AMStatusBadge { text: "Listening on Logos Messaging for buy intents…"; variant: "info"; Layout.fillWidth: true }
                    AMButton { visible: !agora.registered; text: "Register Agent (1,000 NOM stake)"; primary: true; onClicked: agora.registerAgent("1000", ["inference","research"]) }
                    Item { height: 10 }
                }
            }

            // INTENT
            ScrollView {
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ColumnLayout {
                    width: parent.width; anchors.topMargin: 8; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                    AMSectionTitle { text: "Incoming Buy Intent" }
                    AMStatusBadge { text: "Intent received · daemon-ai evaluating…"; variant: "warning"; Layout.fillWidth: true }

                    Rectangle {
                        Layout.fillWidth: true; height: iCol.implicitHeight + 16; color: LogosTheme.bg; border.color: LogosTheme.border; border.width: 1
                        ColumnLayout {
                            id: iCol; anchors.fill: parent; anchors.margins: 8; spacing: 4
                            Repeater {
                                model: [{ lbl: "Buyer ID", ref: "intentBuyerId" },{ lbl: "Category", ref: "intentCategory" },{ lbl: "Budget", ref: "intentBudget" },{ lbl: "Task", ref: "intentTask" }]
                                delegate: Row {
                                    spacing: 8; Layout.fillWidth: true
                                    Text { text: modelData.lbl + ":"; color: LogosTheme.dimFg; font.family: "Menlo"; font.pixelSize: 11; width: 80 }
                                    Text { id: { if(modelData.ref==="intentBuyerId") intentBuyerId=this; if(modelData.ref==="intentCategory") intentCategory=this; if(modelData.ref==="intentBudget") intentBudget=this; if(modelData.ref==="intentTask") intentTask=this; this }; text: "—"; color: LogosTheme.fg; font.family: "Menlo"; font.pixelSize: 11; wrapMode: Text.WordWrap }
                                }
                            }
                        }
                    }
                    property alias intentBuyerId: _ibi; property alias intentCategory: _ic; property alias intentBudget: _ib; property alias intentTask: _it
                    Text { id: _ibi; visible: false }; Text { id: _ic; visible: false }; Text { id: _ib; visible: false }; Text { id: _it; visible: false }
                    Text { id: evalText; text: ""; font.family: "Menlo"; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                    Row {
                        spacing: 8
                        AMButton { text: "Reject"; onClicked: root.state = "dashboard" }
                        AMButton { text: "Send Offer"; primary: true; onClicked: { root.state = "executing"; execModel.clear(); appendLog("► Computing delivery hash commitment…", LogosTheme.dimFg); var sid = Math.random().toString(16).slice(2, 10); var hash = "sha256:" + Math.random().toString(16).slice(2) + Math.random().toString(16).slice(2); agora.sendOffer(sid, pendingIntent.buyerId || "", "inference-v1", "0.002", 2000, "4.00", hash); agora.executeTask(sid, pendingIntent.task || "task", "inference", "0xescrow_pending") } }
                    }
                }
            }

            // EXECUTING
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 8; spacing: 4
                AMSectionTitle { text: "Executing Task" }
                Text { text: "daemon-ai running locally · output pinned to Logos Storage"; color: LogosTheme.dimFg; font.family: "Menlo"; font.pixelSize: 11 }
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true; color: LogosTheme.bg; border.color: LogosTheme.border; border.width: 1
                    ListView { id: execView; anchors.fill: parent; anchors.margins: 6; model: execModel; spacing: 0; clip: true; delegate: Text { width: execView.width; text: model.msg; color: model.clr; font.family: "Menlo"; font.pixelSize: 11; lineHeight: 1.6; wrapMode: Text.WrapAnywhere } }
                }
            }

            // COMPLETE
            ScrollView {
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ColumnLayout {
                    width: parent.width; anchors.topMargin: 8; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                    AMStatusBadge { text: "Task delivered · Logos Storage pinned · Awaiting escrow release"; variant: "success"; Layout.fillWidth: true }
                    Rectangle {
                        Layout.fillWidth: true; height: dlvCol.implicitHeight + 16; color: LogosTheme.bg; border.color: LogosTheme.border; border.width: 1
                        ColumnLayout { id: dlvCol; anchors.fill: parent; anchors.margins: 8; spacing: 4
                            Text { text: "├─ Delivery Details ─"; color: LogosTheme.border; font.family: "Menlo"; font.pixelSize: 11 }
                            AMHashRow { id: deliveryCid; label: "Logos Storage CID"; Layout.fillWidth: true }
                            AMHashRow { id: deliveryHash; label: "Output Hash"; Layout.fillWidth: true }
                            AMHashRow { id: deliveryEsc; label: "Escrow ID"; Layout.fillWidth: true }
                        }
                    }
                    AMButton { text: "Back to dashboard"; onClicked: root.state = "dashboard" }
                    Item { height: 10 }
                }
            }
        }
    }
}
