// FeedView.qml — WeeChat TUI style live feed (chat-like log)
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Item {
    id: root

    function addEvent(e) {
        feedModel.insert(0, { icon: e.icon || "◈", title: e.title || "", sub: e.sub || "", amount: e.amount || "", ts: e.ts || Date.now() })
        if (feedModel.count > 100) feedModel.remove(feedModel.count - 1)
    }

    Component.onCompleted: {
        agora.subscribeFeed()
        var seeds = [
            { icon:"◈", title:"Capability broadcast",  sub:"NullNode Prime · inference · 0.002 NOM/token", amount:"",         ts: Date.now()-180000 },
            { icon:"↓", title:"Buy intent",            sub:"anon buyer · inference · budget 50 NOM",       amount:"",         ts: Date.now()-150000 },
            { icon:"·", title:"Offer accepted",        sub:"session a1b2c3d4 · NullNode Prime",            amount:"4.20 NOM", ts: Date.now()-140000 },
            { icon:"$", title:"Escrow created",        sub:"LSSA · Blend Network private",                 amount:"4.20 NOM", ts: Date.now()-139000 },
            { icon:">", title:"Delivery pinned",       sub:"Logos Storage · QmXk3Np9r2…",                  amount:"",         ts: Date.now()-130000 },
            { icon:"✓", title:"Escrow released",       sub:"private transfer · Blend Network",             amount:"4.20 NOM", ts: Date.now()-129000 },
            { icon:"★", title:"Reputation updated",    sub:"NullNode Prime · 96.1% → 96.2%",               amount:"",         ts: Date.now()-128000 },
            { icon:"↓", title:"Buy intent",            sub:"anon buyer · research · budget 100 NOM",       amount:"",         ts: Date.now()-90000  },
            { icon:"·", title:"Offer accepted",        sub:"session b5c6d7e8 · DataDaemon Alpha",          amount:"28.50 NOM",ts: Date.now()-80000  },
            { icon:"$", title:"Escrow created",        sub:"LSSA · Blend Network private",                 amount:"28.50 NOM",ts: Date.now()-79000  },
        ]
        for (var i = 0; i < seeds.length; ++i) feedModel.append(seeds[i])
    }
    Component.onDestruction: agora.unsubscribeFeed()

    ListModel { id: feedModel }

    Rectangle {
        anchors.fill: parent; color: DSTheme.bg

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 8; spacing: 4

            AMSectionTitle { text: "Live Trade Feed" }
            Text { text: "Real-time Agora activity via Logos Messaging · amounts private on Logos Blockchain"; color: DSTheme.dimFg; font.family: "Menlo"; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true }

            AMStatusBadge { text: "Subscribed to /agora/1/capabilities/json and /agora/1/intents/json"; variant: "info"; Layout.fillWidth: true }

            // Column header
            Rectangle {
                Layout.fillWidth: true; height: 18; color: DSTheme.statusBg
                Row {
                    anchors.fill: parent; anchors.leftMargin: 6; spacing: 0
                    Text { text: "TIME";   width: 60;  color: DSTheme.dimFg; font.family: "Menlo"; font.pixelSize: 10; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: " ";      width: 20;  anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "EVENT";  width: 180; color: DSTheme.dimFg; font.family: "Menlo"; font.pixelSize: 10; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "DETAILS"; color: DSTheme.dimFg; font.family: "Menlo"; font.pixelSize: 10; font.bold: true; anchors.verticalCenter: parent.verticalCenter; Layout.fillWidth: true }
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: DSTheme.border }

            ListView {
                id: feedList
                Layout.fillWidth: true; Layout.fillHeight: true
                model: feedModel; spacing: 0; clip: true
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Rectangle {
                    width: feedList.width; height: 20
                    color: itemMa.containsMouse ? DSTheme.statusBg : index % 2 === 0 ? DSTheme.bg : DSTheme.altBg
                    MouseArea { id: itemMa; anchors.fill: parent; hoverEnabled: true }

                    Row {
                        anchors.fill: parent; anchors.leftMargin: 6; spacing: 0

                        // Timestamp
                        Text {
                            text: {
                                var s = Math.floor((Date.now() - model.ts) / 1000)
                                if (s < 60)   return s + "s ago"
                                if (s < 3600) return Math.floor(s/60)  + "m ago"
                                return Math.floor(s/3600) + "h ago"
                            }
                            color: DSTheme.dimFg; font.family: "Menlo"; font.pixelSize: 10; width: 60
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Icon
                        Text {
                            text: model.icon; font.family: "Menlo"; font.pixelSize: 12; width: 20
                            color: DSTheme.yellow; anchors.verticalCenter: parent.verticalCenter
                        }

                        // Event title
                        Text {
                            text: model.title; color: DSTheme.fg; font.family: "Menlo"; font.pixelSize: 11; width: 180
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Details
                        Text {
                            text: model.sub; color: DSTheme.dimFg; font.family: "Menlo"; font.pixelSize: 10
                            anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                        }

                        Item { width: 8; height: 1 }

                        // Amount
                        Text {
                            text: model.amount; color: DSTheme.blue; font.family: "Menlo"; font.pixelSize: 11; font.bold: true
                            visible: model.amount !== ""; anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }
    }
}
