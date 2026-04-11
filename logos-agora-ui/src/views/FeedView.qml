// FeedView.qml
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Item {
    id: root

    // ── Public API ────────────────────────────────────────────────
    function addEvent(e) {
        feedModel.insert(0, {
            icon:  e.icon        || "◈",
            title: e.title       || "",
            sub:   e.sub         || "",
            amount:e.amount      || "",
            ts:    e.ts          || Date.now()
        })
        // Cap list at 100 items
        if (feedModel.count > 100) feedModel.remove(feedModel.count - 1)
    }

    Component.onCompleted: {
        agora.subscribeFeed()
        // Seed with example events so the view isn't empty on first open
        var seeds = [
            { icon:"◈", title:"Capability broadcast",  sub:"NullNode Prime · inference · 0.002 NOM/token", amount:"",         ts: Date.now()-180000 },
            { icon:"↓", title:"Buy intent",            sub:"anon buyer · inference · budget 50 NOM",       amount:"",         ts: Date.now()-150000 },
            { icon:"🤝",title:"Offer accepted",        sub:"session a1b2c3d4 · NullNode Prime",            amount:"4.20 NOM", ts: Date.now()-140000 },
            { icon:"🔒",title:"Escrow created",        sub:"LSSA · Blend Network private",                 amount:"4.20 NOM", ts: Date.now()-139000 },
            { icon:"📦",title:"Delivery pinned",       sub:"Logos Storage · QmXk3Np9r2…",                  amount:"",         ts: Date.now()-130000 },
            { icon:"✓", title:"Escrow released",       sub:"private transfer · Blend Network",             amount:"4.20 NOM", ts: Date.now()-129000 },
            { icon:"⭐",title:"Reputation updated",    sub:"NullNode Prime · 96.1% → 96.2%",               amount:"",         ts: Date.now()-128000 },
            { icon:"↓", title:"Buy intent",            sub:"anon buyer · research · budget 100 NOM",       amount:"",         ts: Date.now()-90000  },
            { icon:"🤝",title:"Offer accepted",        sub:"session b5c6d7e8 · DataDaemon Alpha",          amount:"28.50 NOM",ts: Date.now()-80000  },
            { icon:"🔒",title:"Escrow created",        sub:"LSSA · Blend Network private",                 amount:"28.50 NOM",ts: Date.now()-79000  },
        ]
        for (var i = 0; i < seeds.length; ++i) feedModel.append(seeds[i])
    }

    Component.onDestruction: agora.unsubscribeFeed()

    // ── Model ─────────────────────────────────────────────────────
    ListModel { id: feedModel }

    // ── Layout ────────────────────────────────────────────────────
    ColumnLayout {
        anchors { fill: parent; margins: 20 }
        spacing: 12

        AMSectionTitle { text: "Live Trade Feed" }
        Text {
            text: "Real-time Agora activity via Logos Messaging · amounts private on Logos Blockchain"
            color: "#8b91a8"; font.pixelSize: 12
            wrapMode: Text.WordWrap; Layout.fillWidth: true
        }

        AMStatusBadge {
            text: "Subscribed to /agora/1/capabilities/json and /agora/1/intents/json"
            variant: "info"
            Layout.fillWidth: true
        }

        ListView {
            id: feedList
            Layout.fillWidth: true; Layout.fillHeight: true
            model: feedModel
            spacing: 6; clip: true
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            add: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 300 }
                NumberAnimation { property: "y";       from: -8; to: 0; duration: 300; easing.type: Easing.OutCubic }
            }

            delegate: Rectangle {
                id: feedItem
                width: feedList.width
                height: itemRow.implicitHeight + 20
                color:        itemMa.containsMouse ? "#1c1f2e" : "#141720"
                border.color: itemMa.containsMouse ? "#2f3550" : "#252a3d"
                border.width: 1; radius: 8
                Behavior on color { ColorAnimation { duration: 80 } }

                MouseArea { id: itemMa; anchors.fill: parent; hoverEnabled: true }

                RowLayout {
                    id: itemRow
                    anchors { fill: parent; margins: 12 }
                    spacing: 11

                    Text {
                        text:           model.icon
                        font.pixelSize: 15
                        Layout.preferredWidth: 22
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Column {
                        spacing: 3; Layout.fillWidth: true
                        Text { text: model.title; color: "#e8eaf0"; font.pixelSize: 12; font.weight: Font.Medium }
                        Text { text: model.sub;   color: "#555d7a"; font.pixelSize: 10; font.family: "Menlo, monospace"; wrapMode: Text.WrapAnywhere; width: parent.width }
                    }

                    Text {
                        text:           model.amount
                        color:          "#7c6af7"
                        font.pixelSize: 12; font.weight: Font.Bold
                        visible:        model.amount !== ""
                    }

                    Text {
                        text: {
                            var s = Math.floor((Date.now() - model.ts) / 1000)
                            if (s < 60)   return s + "s ago"
                            if (s < 3600) return Math.floor(s/60)  + "m ago"
                            return Math.floor(s/3600) + "h ago"
                        }
                        color:          "#3a4060"
                        font.pixelSize: 10
                    }
                }
            }
        }
    }
}
