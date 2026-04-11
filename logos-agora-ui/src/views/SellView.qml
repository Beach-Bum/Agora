// SellView.qml
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Item {
    id: root

    // dashboard | intent | executing | complete
    property string state: "dashboard"

    property var pendingIntent: ({})

    // ── Public API ────────────────────────────────────────────────
    function onIntentReceived(intent) {
        pendingIntent = intent
        intentBuyerId.text   = intent.buyerId   ? intent.buyerId.slice(0,20)+"…"   : "—"
        intentCategory.text  = intent.category  || "—"
        intentBudget.text    = (intent.budget    || "—") + " NOM"
        intentTask.text      = intent.task       || "—"
        evalText.text        = ""
        evalText.color       = "#8b91a8"
        root.state = "intent"
    }

    function onDaemonEval(action, reason) {
        var ok = action === "accept"
        evalText.text  = (ok ? "✓ " : "✗ ") + action.charAt(0).toUpperCase() + action.slice(1) + " — " + reason
        evalText.color = ok ? "#2fb67a" : "#f59f00"
    }

    function onOfferSent(sessionId) {
        appendLog("  Offer sent · session " + sessionId.slice(0,8) + "…", "#2fb67a")
    }

    function appendLog(msg, color) {
        execModel.append({ msg: msg, clr: color || "#555d7a" })
        execView.positionViewAtEnd()
    }

    function onTaskComplete(result) {
        deliveryCid.value  = result.cid    ? result.cid.slice(0,30)+"…"    : "—"
        deliveryHash.value = result.hash   ? result.hash.slice(0,42)+"…"   : "—"
        deliveryEsc.value  = result.escrowId ? result.escrowId.slice(0,28)+"…" : "—"
        root.state = "complete"
    }

    // ── Models ────────────────────────────────────────────────────
    ListModel { id: execModel }

    // ── Views ─────────────────────────────────────────────────────
    StackLayout {
        anchors.fill: parent
        currentIndex: ["dashboard","intent","executing","complete"].indexOf(root.state)

        // ── DASHBOARD ─────────────────────────────────────────────
        ScrollView {
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: parent.width
                anchors { topMargin: 20; leftMargin: 20; rightMargin: 20 }
                spacing: 14

                AMSectionTitle { text: "Sell Service" }
                Text {
                    text: "daemon-ai evaluates intents · Logos Messaging sends offers · Logos Blockchain settles"
                    color: "#8b91a8"; font.pixelSize: 12
                    wrapMode: Text.WordWrap; Layout.fillWidth: true
                }

                // Stats
                RowLayout {
                    spacing: 10; Layout.fillWidth: true
                    Repeater {
                        model: [
                            { lbl: "NOM Balance", val: agora.balance  || "—", clr: "#7c6af7" },
                            { lbl: "NOM Staked",  val: agora.stake    || "—", clr: "#2fb67a" },
                            { lbl: "Reputation",  val: agora.reputation > 0 ? (agora.reputation * 100).toFixed(1) + "%" : "—", clr: "#f59f00" },
                        ]
                        delegate: Rectangle {
                            Layout.fillWidth: true; height: 70
                            color: "#141720"; border.color: "#252a3d"; border.width: 1; radius: 10
                            Column {
                                anchors.centerIn: parent; spacing: 4
                                Text { text: modelData.val; color: modelData.clr; font.pixelSize: 20; font.weight: Font.Bold; horizontalAlignment: Text.AlignHCenter; anchors.horizontalCenter: parent.horizontalCenter }
                                Text { text: modelData.lbl; color: "#8b91a8"; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter; anchors.horizontalCenter: parent.horizontalCenter }
                            }
                        }
                    }
                }

                // Agent info
                Rectangle {
                    Layout.fillWidth: true; height: agentCol.implicitHeight + 24
                    color: "#141720"; border.color: "#252a3d"; border.width: 1; radius: 10
                    ColumnLayout {
                        id: agentCol
                        anchors { fill: parent; margins: 16 }
                        spacing: 8
                        Text { text: "Agent Node"; color: "#e8eaf0"; font.pixelSize: 12; font.weight: Font.Bold; font.letterSpacing: 0.8; opacity: 0.6 }
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Agent ID"; color: "#8b91a8"; font.pixelSize: 11; Layout.minimumWidth: 80 }
                            Text {
                                text: agora.agentId.length > 0 ? agora.agentId.slice(0,22)+"…" : "Not registered"
                                color: "#38b2ac"; font.pixelSize: 10; font.family: "Menlo, monospace"; Layout.fillWidth: true
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Status"; color: "#8b91a8"; font.pixelSize: 11; Layout.minimumWidth: 80 }
                            Text {
                                text: agora.registered ? "✓ Broadcasting via Logos Messaging" : "Not registered"
                                color: agora.registered ? "#2fb67a" : "#f59f00"; font.pixelSize: 11
                            }
                        }
                    }
                }

                // Services offered
                Rectangle {
                    Layout.fillWidth: true; height: svcCol.implicitHeight + 24
                    color: "#141720"; border.color: "#252a3d"; border.width: 1; radius: 10
                    ColumnLayout {
                        id: svcCol
                        anchors { fill: parent; margins: 16 }
                        spacing: 8
                        Text { text: "Services Offered"; color: "#e8eaf0"; font.pixelSize: 12; font.weight: Font.Bold; font.letterSpacing: 0.8; opacity: 0.6 }
                        Repeater {
                            model: [
                                { cat: "inference", id: "inference-v1", price: "0.002 NOM/token", lat: "~850ms" },
                                { cat: "research",  id: "research-v1",  price: "10 NOM/report",   lat: "~8s"    },
                            ]
                            delegate: RowLayout {
                                Layout.fillWidth: true; spacing: 8
                                AMTag { text: modelData.cat }
                                Text { text: modelData.id; color: "#555d7a"; font.pixelSize: 10; font.family: "Menlo, monospace"; Layout.fillWidth: true }
                                Text { text: modelData.price; color: "#7c6af7"; font.pixelSize: 11; font.weight: Font.Bold }
                                Text { text: modelData.lat;   color: "#555d7a"; font.pixelSize: 10 }
                            }
                        }
                    }
                }

                // Listening badge
                AMStatusBadge { text: "Listening on Logos Messaging for buy intents…"; variant: "info"; Layout.fillWidth: true }

                AMButton {
                    visible: !agora.registered
                    text: "Register Agent (1,000 NOM stake)"; primary: true
                    onClicked: agora.registerAgent("1000", ["inference","research"])
                }

                Item { height: 20 }
            }
        }

        // ── INTENT ────────────────────────────────────────────────
        ScrollView {
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: parent.width
                anchors { topMargin: 20; leftMargin: 20; rightMargin: 20 }
                spacing: 12

                AMSectionTitle { text: "Incoming Buy Intent" }
                AMStatusBadge { text: "⚡  Intent received · daemon-ai evaluating…"; variant: "warning"; Layout.fillWidth: true }

                Rectangle {
                    Layout.fillWidth: true; height: iCol.implicitHeight + 24
                    color: "#141720"; border.color: "#252a3d"; border.width: 1; radius: 10
                    ColumnLayout {
                        id: iCol
                        anchors { fill: parent; margins: 16 }
                        spacing: 10
                        Repeater {
                            model: [
                                { lbl: "Buyer ID",  ref: "intentBuyerId"  },
                                { lbl: "Category",  ref: "intentCategory" },
                                { lbl: "Budget",    ref: "intentBudget"   },
                                { lbl: "Task",      ref: "intentTask"     },
                            ]
                            delegate: RowLayout {
                                Layout.fillWidth: true
                                Text { text: modelData.lbl; color: "#8b91a8"; font.pixelSize: 11; Layout.minimumWidth: 80 }
                                Text {
                                    id: {
                                        if (modelData.ref === "intentBuyerId")  intentBuyerId  = this
                                        if (modelData.ref === "intentCategory") intentCategory = this
                                        if (modelData.ref === "intentBudget")   intentBudget   = this
                                        if (modelData.ref === "intentTask")     intentTask     = this
                                        this
                                    }
                                    text: "—"; color: "#e8eaf0"; font.pixelSize: 11; Layout.fillWidth: true; wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }

                property alias intentBuyerId:  _ibi
                property alias intentCategory: _ic
                property alias intentBudget:   _ib
                property alias intentTask:     _it
                Text { id: _ibi; visible: false }; Text { id: _ic; visible: false }
                Text { id: _ib;  visible: false }; Text { id: _it; visible: false }

                Text { id: evalText; text: ""; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }

                RowLayout {
                    spacing: 10
                    AMButton { text: "Reject"; onClicked: root.state = "dashboard" }
                    AMButton {
                        text: "Send Offer"; primary: true
                        onClicked: {
                            root.state = "executing"
                            execModel.clear()
                            appendLog("► Computing delivery hash commitment…", "#555d7a")
                            var sid = Math.random().toString(16).slice(2, 10)
                            var hash = "sha256:" + Math.random().toString(16).slice(2) + Math.random().toString(16).slice(2)
                            agora.sendOffer(sid, pendingIntent.buyerId || "", "inference-v1",
                                "0.002", 2000, "4.00", hash)
                            agora.executeTask(sid, pendingIntent.task || "task", "inference", "0xescrow_pending")
                        }
                    }
                }
            }
        }

        // ── EXECUTING ─────────────────────────────────────────────
        ColumnLayout {
            anchors { fill: parent; margins: 20 }
            spacing: 12

            AMSectionTitle { text: "Executing Task" }
            Text { text: "daemon-ai running locally · no tools · output pinned to Logos Storage"; color: "#8b91a8"; font.pixelSize: 12 }

            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                color: "#060810"; border.color: "#252a3d"; border.width: 1; radius: 8

                ListView {
                    id: execView
                    anchors { fill: parent; margins: 12 }
                    model: execModel; spacing: 0; clip: true
                    delegate: Text {
                        width: execView.width; text: model.msg; color: model.clr
                        font.family: "Menlo, monospace"; font.pixelSize: 11
                        lineHeight: 1.8; wrapMode: Text.WrapAnywhere
                    }
                }
            }
        }

        // ── COMPLETE ──────────────────────────────────────────────
        ScrollView {
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: parent.width
                anchors { topMargin: 20; leftMargin: 20; rightMargin: 20 }
                spacing: 12

                AMStatusBadge { text: "✓  Task delivered · Logos Storage pinned · Awaiting escrow release"; variant: "success"; Layout.fillWidth: true }

                Rectangle {
                    Layout.fillWidth: true; height: dlvCol.implicitHeight + 24
                    color: "#141720"; border.color: "#252a3d"; border.width: 1; radius: 10
                    ColumnLayout {
                        id: dlvCol
                        anchors { fill: parent; margins: 16 }
                        spacing: 8
                        Text { text: "Delivery Details"; color: "#e8eaf0"; font.pixelSize: 12; font.weight: Font.Bold; font.letterSpacing: 0.8; opacity: 0.6 }
                        AMHashRow { id: deliveryCid;  label: "Logos Storage CID"; Layout.fillWidth: true }
                        AMHashRow { id: deliveryHash; label: "Output Hash";       Layout.fillWidth: true }
                        AMHashRow { id: deliveryEsc;  label: "Escrow ID";         Layout.fillWidth: true }
                    }
                }

                AMButton { text: "← Back to dashboard"; onClicked: root.state = "dashboard" }
                Item { height: 20 }
            }
        }
    }
}
