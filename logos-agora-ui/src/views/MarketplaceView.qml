// MarketplaceView.qml
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Item {
    id: root

    // ── Public API ────────────────────────────────────────────────
    function populate(agentList) {
        agentModel.clear()
        for (var i = 0; i < agentList.length; ++i) {
            var a = agentList[i]
            agentModel.append({
                agentId:  a.agentId  || "",
                name:     a.name     || ("Agent " + i),
                stake:    a.stake    || "0",
                rep:      parseFloat(a.reputation) || 0.5,
                services: (a.services || []).join(", "),
                price:    a.pricePerToken || a.pricePerUnit || "—",
                latency:  a.avgLatencyMs ? "~" + a.avgLatencyMs + "ms" : "—"
            })
        }
    }

    property string activeFilter: "All"

    Component.onCompleted: agora.loadMarketplace()

    ListModel { id: agentModel }

    // ── Layout ────────────────────────────────────────────────────
    ColumnLayout {
        anchors { fill: parent; margins: 20 }
        spacing: 12

        AMSectionTitle { text: "Active Agents" }

        Text {
            text: "Broadcasting via Logos Messaging · Staked on Logos Blockchain · Reputation on-chain"
            color: "#8b91a8"; font.pixelSize: 12
            wrapMode: Text.WordWrap; Layout.fillWidth: true
        }

        RowLayout {
            spacing: 6; Layout.fillWidth: true

            Repeater {
                model: ["All","Inference","Research","Data","Code","Compute"]
                delegate: AMFilterButton {
                    text:   modelData
                    active: root.activeFilter === modelData
                    onClicked: { root.activeFilter = modelData; agora.loadMarketplace() }
                }
            }
            Item { Layout.fillWidth: true }
            Text {
                text:           agentModel.count + " agents online"
                color:          "#555d7a"; font.pixelSize: 11
            }
        }

        ScrollView {
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ListView {
                id: listView
                width: parent.width
                model: agentModel
                spacing: 8; clip: true

                Text {
                    anchors.centerIn: parent
                    visible: agentModel.count === 0
                    text: "Scanning Logos Messaging network…"
                    color: "#555d7a"; font.pixelSize: 12
                }

                delegate: Rectangle {
                    id: card
                    width: listView.width
                    height: col.implicitHeight + 24
                    color:        ma.containsMouse ? "#1c1f2e" : "#141720"
                    border.color: ma.containsMouse ? "#3a4060" : "#252a3d"
                    border.width: 1; radius: 10
                    Behavior on color        { ColorAnimation { duration: 80 } }
                    Behavior on border.color { ColorAnimation { duration: 80 } }

                    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }

                    ColumnLayout {
                        id: col
                        anchors { fill: parent; margins: 14 }
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: model.name; color: "#e8eaf0"; font.pixelSize: 13; font.weight: Font.Bold; Layout.fillWidth: true }
                            Column {
                                spacing: 2
                                Text { text: model.price;   color: "#7c6af7"; font.pixelSize: 12; font.weight: Font.Bold; horizontalAlignment: Text.AlignRight }
                                Text { text: model.latency; color: "#555d7a"; font.pixelSize: 10; horizontalAlignment: Text.AlignRight }
                            }
                        }

                        Text {
                            text: model.agentId.length > 26 ? model.agentId.slice(0,20)+"…"+model.agentId.slice(-6) : model.agentId
                            color: "#38b2ac"; font.pixelSize: 10; font.family: "Menlo, monospace"
                        }

                        RowLayout {
                            spacing: 6; Layout.fillWidth: true
                            Repeater {
                                model: card.ListView.view.model.get(index).services.split(", ")
                                delegate: AMTag { text: modelData }
                            }
                            Item { Layout.fillWidth: true }
                            Text { text: model.stake + " NOM staked"; color: "#7c6af7"; font.pixelSize: 11 }
                        }

                        AMRepBar { value: model.rep; Layout.fillWidth: true }
                    }
                }
            }
        }
    }
}
