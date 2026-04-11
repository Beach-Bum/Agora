// AgoraRoot.qml — Agora Logos Basecamp module root (WeeChat TUI style)
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "views"
import "components"

Item {
    id: root
    anchors.fill: parent

    property string currentView: "marketplace"

    // Colors provided by DSTheme singleton
    // Local aliases for readability in this file
    readonly property color tuiBg:       DSTheme.bg
    readonly property color tuiFg:       DSTheme.fg
    readonly property color tuiBlue:     DSTheme.blue
    readonly property color tuiGreen:    DSTheme.cyan
    readonly property color tuiYellow:   DSTheme.yellow
    readonly property color tuiRed:      DSTheme.red
    readonly property color tuiMagenta:  DSTheme.magenta
    readonly property color tuiCyan:     DSTheme.cyan
    readonly property color tuiDimFg:    DSTheme.dimFg
    readonly property color tuiStatusBg: DSTheme.statusBg
    readonly property color tuiActiveBg: DSTheme.activeBg
    readonly property color tuiBorder:   DSTheme.border

    // ── Route all AgoraBridge signals to the correct view ─────────
    Connections {
        target: agora
        function onStatusChanged()     { }
        function onAgentRegistered(record) { }
        function onAgentStatus(status)     { }
        function onAgentChanged()          { }
        function onMarketplaceLoaded(agents) {
            if (marketplaceLoader.item) marketplaceLoader.item.populate(agents)
        }
        function onOffersReceived(offers) {
            if (buyLoader.item)  buyLoader.item.onOffersReceived(offers)
        }
        function onOfferAccepted(sessionId, escrowId) {
            if (buyLoader.item) buyLoader.item.onOfferAccepted(sessionId, escrowId)
        }
        function onBuyLog(message, color) {
            if (buyLoader.item) buyLoader.item.appendLog(message, color)
        }
        function onBuyComplete(receipt) {
            if (buyLoader.item) buyLoader.item.onComplete(receipt)
        }
        function onBuyError(error) {
            if (buyLoader.item) buyLoader.item.onError(error)
        }
        function onIntentReceived(intent) {
            switchView("sell")
            if (sellLoader.item) sellLoader.item.onIntentReceived(intent)
        }
        function onDaemonEvaluation(action, reason) {
            if (sellLoader.item) sellLoader.item.onDaemonEval(action, reason)
        }
        function onOfferSent(sessionId) {
            if (sellLoader.item) sellLoader.item.onOfferSent(sessionId)
        }
        function onSellLog(message, color) {
            if (sellLoader.item) sellLoader.item.appendLog(message, color)
        }
        function onTaskComplete(result) {
            if (sellLoader.item) sellLoader.item.onTaskComplete(result)
        }
        function onWalletState(state) {
            if (walletLoader.item) walletLoader.item.setState(state)
        }
        function onTradeHistory(trades) {
            if (walletLoader.item) walletLoader.item.setHistory(trades)
        }
        function onFeedEvent(event) {
            if (feedLoader.item) feedLoader.item.addEvent(event)
        }
    }

    function switchView(name) {
        root.currentView = name
    }

    // ── Main layout ───────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: tuiBg

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ── Top Title Bar ─────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 22
                color: tuiStatusBg

                RowLayout {
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    spacing: 0

                    Text {
                        text: "⟡ Agora"
                        color: tuiYellow
                        font.family: "Menlo"
                        font.pixelSize: 12
                        font.bold: true
                    }
                    Text {
                        text: " │ "
                        color: tuiBorder
                        font.family: "Menlo"
                        font.pixelSize: 12
                    }
                    Text {
                        text: "v1.0.0"
                        color: tuiDimFg
                        font.family: "Menlo"
                        font.pixelSize: 12
                    }

                    Item { Layout.fillWidth: true }

                    // Stack status indicators
                    Repeater {
                        model: [
                            { label: "msg",    prop: "messagingStatus"  },
                            { label: "chain",  prop: "blockchainStatus" },
                            { label: "store",  prop: "storageStatus"    },
                            { label: "daemon", prop: "daemonAIStatus"   },
                        ]
                        delegate: Row {
                            spacing: 2
                            Text {
                                text: " │ "
                                color: tuiBorder
                                font.family: "Menlo"
                                font.pixelSize: 12
                            }
                            Text {
                                text: modelData.label + ":"
                                color: tuiDimFg
                                font.family: "Menlo"
                                font.pixelSize: 12
                            }
                            Text {
                                text: {
                                    var s = agora[modelData.prop] || ""
                                    return s || "…"
                                }
                                color: {
                                    var s = agora[modelData.prop] || ""
                                    if (s === "live" || s === "local") return tuiGreen
                                    if (s === "mock" || s === "testnet") return tuiYellow
                                    return tuiDimFg
                                }
                                font.family: "Menlo"
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }

            // ── Border line ───────────────────────────────────────
            Rectangle { Layout.fillWidth: true; height: 1; color: tuiBorder }

            // ── Main area: buffer list + content ──────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                // ── Left Buffer List ──────────────────────────────
                Rectangle {
                    Layout.preferredWidth: 180
                    Layout.fillHeight: true
                    color: tuiBg

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        // buffers heading
                        Rectangle {
                            Layout.fillWidth: true
                            height: 20
                            color: "transparent"
                            Text {
                                anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
                                text: "buffers"
                                color: tuiDimFg
                                font.family: "Menlo"
                                font.pixelSize: 12
                            }
                        }

                        // Nav items
                        Repeater {
                            model: [
                                { view: "marketplace", num: "1", icon: "◈", label: "marketplace" },
                                { view: "buy",         num: "2", icon: "↓", label: "buy"         },
                                { view: "sell",        num: "3", icon: "↑", label: "sell"        },
                                { view: "wallet",      num: "4", icon: "◎", label: "wallet"      },
                                { view: "feed",        num: "5", icon: "≋", label: "feed"        },
                            ]
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                height: 20
                                color: root.currentView === modelData.view ? tuiActiveBg : navMa.containsMouse ? tuiStatusBg : "transparent"

                                Row {
                                    anchors { fill: parent; leftMargin: 6 }
                                    spacing: 0

                                    Text {
                                        text: modelData.num + "."
                                        color: tuiDimFg
                                        font.family: "Menlo"
                                        font.pixelSize: 12
                                        width: 20
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: modelData.icon + " "
                                        color: root.currentView === modelData.view ? tuiYellow : tuiDimFg
                                        font.family: "Menlo"
                                        font.pixelSize: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: modelData.label
                                        color: root.currentView === modelData.view ? tuiFg : tuiBlue
                                        font.family: "Menlo"
                                        font.pixelSize: 12
                                        font.bold: root.currentView === modelData.view
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: navMa; anchors.fill: parent
                                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.switchView(modelData.view)
                                        if (modelData.view === "wallet") agora.getWalletState()
                                        if (modelData.view === "feed")   agora.subscribeFeed()
                                    }
                                }
                            }
                        }

                        // Separator
                        Item { Layout.preferredHeight: 8 }
                        Rectangle {
                            Layout.fillWidth: true; height: 1
                            color: tuiBorder; Layout.leftMargin: 6; Layout.rightMargin: 6
                        }
                        Item { Layout.preferredHeight: 4 }

                        // Stack section heading
                        Rectangle {
                            Layout.fillWidth: true; height: 20; color: "transparent"
                            Text {
                                anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
                                text: "stack"
                                color: tuiDimFg
                                font.family: "Menlo"
                                font.pixelSize: 12
                            }
                        }

                        // Stack status rows
                        Repeater {
                            model: [
                                { label: "messaging",  prop: "messagingStatus"  },
                                { label: "blockchain", prop: "blockchainStatus" },
                                { label: "storage",    prop: "storageStatus"    },
                                { label: "daemon-ai",  prop: "daemonAIStatus"   },
                            ]
                            delegate: Rectangle {
                                Layout.fillWidth: true; height: 18; color: "transparent"
                                Row {
                                    anchors { fill: parent; leftMargin: 8 }
                                    spacing: 4
                                    Text {
                                        text: "●"
                                        color: {
                                            var s = agora[modelData.prop] || ""
                                            if (s === "live" || s === "local") return tuiGreen
                                            if (s === "mock" || s === "testnet") return tuiYellow
                                            return tuiDimFg
                                        }
                                        font.pixelSize: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: modelData.label
                                        color: tuiDimFg
                                        font.family: "Menlo"
                                        font.pixelSize: 11
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Item { width: 4; height: 1 }
                                    Text {
                                        text: agora[modelData.prop] || "…"
                                        color: tuiDimFg
                                        font.family: "Menlo"
                                        font.pixelSize: 11
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }

                        // Separator
                        Item { Layout.preferredHeight: 8 }
                        Rectangle {
                            Layout.fillWidth: true; height: 1
                            color: tuiBorder; Layout.leftMargin: 6; Layout.rightMargin: 6
                        }
                        Item { Layout.preferredHeight: 4 }

                        // Theme picker
                        Rectangle {
                            Layout.fillWidth: true; height: 20; color: "transparent"
                            Text {
                                anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
                                text: "themes"
                                color: tuiDimFg
                                font.family: "Menlo"
                                font.pixelSize: 12
                            }
                        }

                        Repeater {
                            model: DSTheme.themeNames
                            delegate: Rectangle {
                                Layout.fillWidth: true; height: 18
                                color: DSTheme.currentTheme === modelData ? tuiActiveBg : themeMa.containsMouse ? tuiStatusBg : "transparent"

                                Row {
                                    anchors { fill: parent; leftMargin: 10 }
                                    spacing: 6
                                    Text {
                                        text: DSTheme.currentTheme === modelData ? "✓" : " "
                                        color: tuiGreen
                                        font.family: "Menlo"
                                        font.pixelSize: 11
                                        width: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: modelData
                                        color: DSTheme.currentTheme === modelData ? tuiFg : tuiBlue
                                        font.family: "Menlo"
                                        font.pixelSize: 11
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: themeMa; anchors.fill: parent
                                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: DSTheme.setTheme(modelData)
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }

                        // Agent info at bottom
                        Rectangle {
                            Layout.fillWidth: true; height: 1; color: tuiBorder
                            Layout.leftMargin: 6; Layout.rightMargin: 6
                        }
                        Rectangle {
                            Layout.fillWidth: true; height: 38; color: "transparent"
                            Column {
                                anchors { fill: parent; margins: 6 }
                                spacing: 2
                                Text {
                                    text: agora.agentId.length > 0 ? agora.agentId.slice(0,20) + "…" : "not registered"
                                    color: tuiDimFg
                                    font.family: "Menlo"
                                    font.pixelSize: 10
                                    elide: Text.ElideMiddle
                                    width: parent.width
                                }
                                Row {
                                    spacing: 8
                                    Text { text: (agora.balance || "—") + " NOM"; color: tuiBlue; font.family: "Menlo"; font.pixelSize: 11 }
                                    Text { text: agora.reputation > 0 ? (agora.reputation * 100).toFixed(1) + "%" : "—"; color: tuiGreen; font.family: "Menlo"; font.pixelSize: 11 }
                                }
                            }
                        }
                    }
                }

                // ── Vertical border ───────────────────────────────
                Rectangle { Layout.fillHeight: true; width: 1; color: tuiBorder }

                // ── Main content area ─────────────────────────────
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Loader {
                        id: marketplaceLoader
                        anchors.fill: parent
                        active: root.currentView === "marketplace"
                        source: "views/MarketplaceView.qml"
                    }
                    Loader {
                        id: buyLoader
                        anchors.fill: parent
                        active: root.currentView === "buy"
                        source: "views/BuyView.qml"
                    }
                    Loader {
                        id: sellLoader
                        anchors.fill: parent
                        active: root.currentView === "sell"
                        source: "views/SellView.qml"
                    }
                    Loader {
                        id: walletLoader
                        anchors.fill: parent
                        active: root.currentView === "wallet"
                        source: "views/WalletView.qml"
                    }
                    Loader {
                        id: feedLoader
                        anchors.fill: parent
                        active: root.currentView === "feed"
                        source: "views/FeedView.qml"
                    }
                }
            }

            // ── Border line ───────────────────────────────────────
            Rectangle { Layout.fillWidth: true; height: 1; color: tuiBorder }

            // ── Bottom Status Bar ─────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 20
                color: tuiStatusBg

                RowLayout {
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    spacing: 0

                    Text {
                        text: "[" + root.currentView + "]"
                        color: tuiFg
                        font.family: "Menlo"
                        font.pixelSize: 12
                        font.bold: true
                    }
                    Text {
                        text: " │ "
                        color: tuiBorder
                        font.family: "Menlo"
                        font.pixelSize: 12
                    }
                    Text {
                        text: "Agora Marketplace"
                        color: tuiBlue
                        font.family: "Menlo"
                        font.pixelSize: 12
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "1:marketplace 2:buy 3:sell 4:wallet 5:feed"
                        color: tuiDimFg
                        font.family: "Menlo"
                        font.pixelSize: 11
                    }
                }
            }

            // ── Input Line ────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 22
                color: tuiBg

                RowLayout {
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    spacing: 4

                    Text {
                        text: ">"
                        color: tuiYellow
                        font.family: "Menlo"
                        font.pixelSize: 12
                        font.bold: true
                    }
                    Text {
                        text: "type : for commands, / for search"
                        color: tuiDimFg
                        font.family: "Menlo"
                        font.pixelSize: 12
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: {
                            var d = new Date()
                            return d.getHours().toString().padStart(2,'0') + ":" +
                                   d.getMinutes().toString().padStart(2,'0') + ":" +
                                   d.getSeconds().toString().padStart(2,'0')
                        }
                        color: tuiDimFg
                        font.family: "Menlo"
                        font.pixelSize: 12

                        Timer {
                            interval: 1000; running: true; repeat: true
                            onTriggered: parent.text = Qt.binding(function() {
                                var d = new Date()
                                return d.getHours().toString().padStart(2,'0') + ":" +
                                       d.getMinutes().toString().padStart(2,'0') + ":" +
                                       d.getSeconds().toString().padStart(2,'0')
                            })
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        agora.checkNodeStatus()
        agora.loadMarketplace()
    }
}
