// AgoraRoot.qml — Agora Logos Basecamp module root
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "views"
import "components"

Item {
    id: root
    anchors.fill: parent

    property string currentView: "marketplace"

    // ── Route all AgoraBridge signals to the correct view ─────────
    Connections {
        target: agora

        // Status
        function onStatusChanged()     { }   // sidebar dots update via Q_PROPERTY bindings

        // Identity
        function onAgentRegistered(record) { sidebar.updateAgent() }
        function onAgentStatus(status)     { sidebar.updateAgent() }
        function onAgentChanged()          { sidebar.updateAgent() }

        // Marketplace
        function onMarketplaceLoaded(agents) {
            if (marketplaceLoader.item) marketplaceLoader.item.populate(agents)
        }

        // Buy flow
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

        // Sell flow
        function onIntentReceived(intent) {
            // Switch to sell view and show the intent
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

        // Wallet
        function onWalletState(state) {
            if (walletLoader.item) walletLoader.item.setState(state)
        }
        function onTradeHistory(trades) {
            if (walletLoader.item) walletLoader.item.setHistory(trades)
        }

        // Feed
        function onFeedEvent(event) {
            if (feedLoader.item) feedLoader.item.addEvent(event)
        }
    }

    function switchView(name) {
        root.currentView = name
    }

    // ── Main layout ───────────────────────────────────────────────
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Sidebar ───────────────────────────────────────────────
        Rectangle {
            id: sidebar
            Layout.preferredWidth: 224
            Layout.fillHeight: true
            color: "#0f1119"

            function updateAgent() {
                agentIdLabel.text  = agora.agentId.length > 0 ? agora.agentId.slice(0,18)+"…" : "Not registered"
                balanceLabel.text  = (agora.balance || "—") + " NOM"
                repLabel.text      = agora.reputation > 0 ? (agora.reputation * 100).toFixed(1) + "%" : "—"
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Logo
                Rectangle {
                    Layout.fillWidth: true
                    height: 64
                    color: "transparent"

                    Rectangle {
                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                        height: 1; color: "#1e2438"
                    }

                    RowLayout {
                        anchors { fill: parent; margins: 16 }
                        spacing: 11

                        Rectangle {
                            width: 34; height: 34; radius: 9
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: "rgba(124,106,247,0.25)" }
                                GradientStop { position: 1.0; color: "rgba(124,106,247,0.08)" }
                            }
                            border.color: "rgba(124,106,247,0.2)"; border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "⟡"; font.pixelSize: 17; color: "#9b8eff"
                            }
                        }

                        Column {
                            spacing: 3
                            Text { text: "Agora";             color: "#e8eaf0"; font.pixelSize: 15; font.weight: Font.Bold; font.letterSpacing: -0.3 }
                            Text { text: "Sovereign marketplace"; color: "#353c57"; font.pixelSize: 10 }
                        }
                    }
                }

                // Nav
                Item { Layout.preferredHeight: 8 }

                Repeater {
                    model: [
                        { view:"marketplace", icon:"◈", label:"Marketplace",  sub:"Browse agents"    },
                        { view:"buy",         icon:"↓", label:"Buy Service",  sub:"Hire an agent"    },
                        { view:"sell",        icon:"↑", label:"Sell Service", sub:"Earn NOM"         },
                        { view:"wallet",      icon:"◎", label:"Wallet",       sub:"Identity & stake" },
                        { view:"feed",        icon:"≋", label:"Live Feed",    sub:"Recent trades"    },
                    ]
                    delegate: Rectangle {
                        Layout.fillWidth: true; height: 50
                        color: "transparent"

                        Rectangle {
                            anchors { fill: parent; leftMargin: 8; rightMargin: 8; topMargin: 1; bottomMargin: 1 }
                            radius: 7
                            color: root.currentView === modelData.view
                                   ? "rgba(124,106,247,0.14)" : navMa.containsMouse
                                   ? "#1c1f2e" : "transparent"
                            border.color: root.currentView === modelData.view ? "rgba(124,106,247,0.2)" : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 80 } }

                            RowLayout {
                                anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                                spacing: 10

                                Text {
                                    text:           modelData.icon
                                    font.pixelSize: 14
                                    color:          root.currentView === modelData.view ? "#9b8eff" : "#555d7a"
                                    Layout.preferredWidth: 18
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                Column {
                                    spacing: 2; Layout.fillWidth: true
                                    Text {
                                        text:           modelData.label
                                        font.pixelSize: 12; font.weight: Font.Medium
                                        color:          root.currentView === modelData.view ? "#9b8eff" : "#9096b0"
                                    }
                                    Text {
                                        text:           modelData.sub
                                        font.pixelSize: 10
                                        color:          root.currentView === modelData.view ? "rgba(124,106,247,0.45)" : "#353c57"
                                    }
                                }
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

                Item { Layout.fillHeight: true }

                // Agent quick stats
                Rectangle {
                    Layout.fillWidth: true; height: 72
                    color: "#08090f"
                    Rectangle { anchors.top: parent.top; Layout.fillWidth: true; width: parent.width; height: 1; color: "#1e2438" }

                    ColumnLayout {
                        anchors { fill: parent; margins: 14 }
                        spacing: 5
                        Text { id: agentIdLabel; text: "Not registered"; color: "#353c57"; font.pixelSize: 10; font.family: "Menlo, monospace"; elide: Text.ElideMiddle; Layout.fillWidth: true }
                        RowLayout {
                            Text { id: balanceLabel; text: "— NOM";  color: "#7c6af7"; font.pixelSize: 12; font.weight: Font.SemiBold }
                            Item { Layout.fillWidth: true }
                            Text { id: repLabel;     text: "—";       color: "#2fb67a"; font.pixelSize: 12; font.weight: Font.SemiBold }
                        }
                    }
                }

                // Stack status
                Rectangle {
                    Layout.fillWidth: true; height: 96
                    color: "#060810"
                    Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: "#1e2438" }

                    ColumnLayout {
                        anchors { fill: parent; margins: 14 }
                        spacing: 6

                        Text { text: "STACK"; color: "#353c57"; font.pixelSize: 9; font.letterSpacing: 1.6 }

                        Repeater {
                            model: [
                                { label:"Logos Messaging",  prop:"messagingStatus"  },
                                { label:"Logos Blockchain", prop:"blockchainStatus" },
                                { label:"Logos Storage",    prop:"storageStatus"    },
                                { label:"daemon-ai",        prop:"daemonAIStatus"   },
                            ]
                            delegate: RowLayout {
                                Layout.fillWidth: true; spacing: 7
                                Rectangle {
                                    width: 6; height: 6; radius: 3
                                    color: {
                                        var s = agora[modelData.prop] || ""
                                        if (s === "live"  || s === "local") return "#2fb67a"
                                        if (s === "mock")                   return "#f59f00"
                                        return "#3a4060"
                                    }
                                    SequentialAnimation on opacity {
                                        loops: Animation.Infinite
                                        NumberAnimation { to: 0.3; duration: 1000 }
                                        NumberAnimation { to: 1.0; duration: 1000 }
                                    }
                                }
                                Text { text: modelData.label; color: "#555d7a"; font.pixelSize: 10; Layout.fillWidth: true }
                                Text { text: agora[modelData.prop] || "…"; color: "#353c57"; font.pixelSize: 9 }
                            }
                        }
                    }
                }
            }
        }

        // ── Main content area ─────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            spacing: 0

            // Top bar
            Rectangle {
                Layout.fillWidth: true; height: 50
                color: "#0f1119"
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#1e2438" }

                RowLayout {
                    anchors { fill: parent; leftMargin: 22; rightMargin: 22 }

                    Text {
                        text: ({
                            marketplace: "Marketplace",
                            buy:         "Buy Service",
                            sell:        "Sell Service",
                            wallet:      "Agent Wallet",
                            feed:        "Live Feed"
                        })[root.currentView] || ""
                        color: "#e8eaf0"; font.pixelSize: 14; font.weight: Font.Bold; font.letterSpacing: -0.2
                    }

                    Item { Layout.fillWidth: true }

                    Repeater {
                        model: [
                            { label:"Logos Messaging",  prop:"messagingStatus"  },
                            { label:"Logos Blockchain", prop:"blockchainStatus" },
                            { label:"daemon-ai",        prop:"daemonAIStatus"   },
                        ]
                        delegate: RowLayout {
                            spacing: 5
                            Rectangle {
                                width: 6; height: 6; radius: 3
                                color: {
                                    var s = agora[modelData.prop] || ""
                                    if (s === "live" || s === "local") return "#2fb67a"
                                    return "#f59f00"
                                }
                            }
                            Text { text: modelData.label; color: "#353c57"; font.pixelSize: 11 }
                        }
                    }
                }
            }

            // View loaders — only the active view is loaded
            Item {
                Layout.fillWidth: true; Layout.fillHeight: true

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
    }

    Component.onCompleted: {
        agora.checkNodeStatus()
        agora.loadMarketplace()
    }
}
