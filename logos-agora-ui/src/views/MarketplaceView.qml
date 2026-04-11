// MarketplaceView.qml — WeeChat TUI style
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Item {
    id: root

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

    Rectangle {
        anchors.fill: parent
        color: DSTheme.bg

        ColumnLayout {
            anchors { fill: parent; margins: 8 }
            spacing: 4

            AMSectionTitle { text: "Active Agents" }

            Text {
                text: "Broadcasting via Logos Messaging · Staked on Logos Blockchain · Reputation on-chain"
                color: DSTheme.dimFg; font.family: "Menlo"; font.pixelSize: 11
                wrapMode: Text.WordWrap; Layout.fillWidth: true
            }

            RowLayout {
                spacing: 4; Layout.fillWidth: true

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
                    text: agentModel.count + " agents online"
                    color: DSTheme.dimFg; font.family: "Menlo"; font.pixelSize: 11
                }
            }

            // Column headers
            Rectangle {
                Layout.fillWidth: true; height: 18
                color: DSTheme.statusBg
                Row {
                    anchors { fill: parent; leftMargin: 6 }
                    spacing: 0
                    Text { text: "NAME";     color: DSTheme.dimFg; font.family: "Menlo"; font.pixelSize: 10; font.bold: true; width: 180; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "ID";       color: DSTheme.dimFg; font.family: "Menlo"; font.pixelSize: 10; font.bold: true; width: 200; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "SERVICES"; color: DSTheme.dimFg; font.family: "Menlo"; font.pixelSize: 10; font.bold: true; width: 140; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "PRICE";    color: DSTheme.dimFg; font.family: "Menlo"; font.pixelSize: 10; font.bold: true; width: 120; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "STAKE";    color: DSTheme.dimFg; font.family: "Menlo"; font.pixelSize: 10; font.bold: true; width: 100; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "REP";      color: DSTheme.dimFg; font.family: "Menlo"; font.pixelSize: 10; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: DSTheme.border }

            ScrollView {
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                ListView {
                    id: listView
                    width: parent.width
                    model: agentModel
                    spacing: 0; clip: true

                    Text {
                        anchors.centerIn: parent
                        visible: agentModel.count === 0
                        text: "Scanning Logos Messaging network…"
                        color: DSTheme.dimFg; font.family: "Menlo"; font.pixelSize: 12
                    }

                    delegate: Rectangle {
                        id: card
                        width: listView.width
                        height: col.implicitHeight + 8
                        color: ma.containsMouse ? DSTheme.statusBg : index % 2 === 0 ? DSTheme.bg : DSTheme.altBg

                        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }

                        ColumnLayout {
                            id: col
                            anchors { fill: parent; margins: 6 }
                            spacing: 2

                            // Main row
                            Row {
                                spacing: 0
                                Layout.fillWidth: true

                                Text { text: model.name;    color: DSTheme.yellow; font.family: "Menlo"; font.pixelSize: 12; font.bold: true; width: 180 }
                                Text {
                                    text: model.agentId.length > 22 ? model.agentId.slice(0,16) + "…" + model.agentId.slice(-6) : model.agentId
                                    color: DSTheme.cyan; font.family: "Menlo"; font.pixelSize: 11; width: 200
                                }
                                Text { text: model.services; color: DSTheme.magenta; font.family: "Menlo"; font.pixelSize: 11; width: 140 }
                                Text { text: model.price;    color: DSTheme.blue; font.family: "Menlo"; font.pixelSize: 11; font.bold: true; width: 120 }
                                Text { text: model.stake + " NOM"; color: DSTheme.blue; font.family: "Menlo"; font.pixelSize: 11; width: 100 }
                            }

                            AMRepBar { value: model.rep; Layout.fillWidth: true }
                        }
                    }
                }
            }
        }
    }
}
