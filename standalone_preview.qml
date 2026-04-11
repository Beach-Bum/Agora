// standalone_preview.qml — Run the Agora UI natively without Logos Basecamp
// Usage: qml standalone_preview.qml
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15

Window {
    id: win
    width: 1080; height: 720
    visible: true
    title: "Agora — Logos Basecamp Module (Standalone Preview)"
    color: "#0a0c14"

    // ── Mock AgoraBridge ──────────────────────────────────────────
    QtObject {
        id: agora

        // Q_PROPERTY equivalents
        property string messagingStatus:  "live"
        property string blockchainStatus: "testnet"
        property string storageStatus:    "mock"
        property string daemonAIStatus:   "local"
        property string agentId:          "0382ad672eef8dcbf356b0a91c7d3dec1f"
        property string balance:          "1,247"
        property string stake:            "12,400"
        property double reputation:       0.961
        property bool   registered:       true

        // Signals
        signal statusChanged()
        signal agentChanged()
        signal agentRegistered(var record)
        signal agentStatus(var status)
        signal marketplaceLoaded(var agents)
        signal offersReceived(var offers)
        signal offerAccepted(string sessionId, string escrowId)
        signal buyLog(string message, string color)
        signal buyComplete(var receipt)
        signal buyError(string error)
        signal intentReceived(var intent)
        signal daemonEvaluation(string action, string reason)
        signal offerSent(string sessionId)
        signal sellLog(string message, string color)
        signal taskComplete(var result)
        signal walletState(var state)
        signal tradeHistory(var trades)
        signal feedEvent(var event)

        // Stubs
        function checkNodeStatus() {}
        function loadMarketplace() {
            var agents = [
                { agentId: "0382ad672eef8dcbf356b0a91c7d3dec1f", name: "NullNode Prime",     stake: "12,400", reputation: 0.961, services: ["inference","research"], pricePerToken: "0.002 NOM/token", avgLatencyMs: 820  },
                { agentId: "03b9edc9b63640e5e872f2d5d371a8c9e0", name: "Ghost Compute",       stake: "8,200",  reputation: 0.894, services: ["inference","code"],     pricePerToken: "0.003 NOM/token", avgLatencyMs: 950  },
                { agentId: "03305d65141137783125f9bc405c71da82", name: "DataDaemon Alpha",    stake: "31,000", reputation: 0.982, services: ["data","research"],      pricePerToken: "0.001 NOM/token", avgLatencyMs: 1200 },
                { agentId: "03d4d31a4031f902102cdcf84335e7a1b2", name: "Sovereign Runner",   stake: "5,600",  reputation: 0.873, services: ["compute","code"],       pricePerToken: "0.004 NOM/token", avgLatencyMs: 1800 },
                { agentId: "02a8e31bc7d940f1e5a3b22c6f08d4e7a9", name: "Cipher Research",    stake: "18,900", reputation: 0.945, services: ["research","data"],      pricePerToken: "8 NOM/report",    avgLatencyMs: 6500 },
            ]
            marketplaceLoaded(agents)
        }
        function broadcastCapabilities(services) {}
        function broadcastIntent(cat, task, budget, maxPrice, maxLat, minRep) {
            buyLog("► Broadcasting intent via Logos Messaging…", "#555d7a")
            buyLog("  category: " + cat, "#555d7a")
            buyLog("  task: " + task, "#555d7a")
            buyLog("  budget: " + budget + " NOM", "#7c6af7")
            _buyTimer.start()
        }
        function acceptOffer(sid, sellerId, price, hash) {}
        function verifyAndRelease(eid, cid, hash) {}
        function evaluateIntent(intent) {}
        function sendOffer(sid, buyerId, capId, ppu, eu, tp, dhc) {
            sellLog("► Sending offer via Logos Messaging…", "#555d7a")
            sellLog("  session: " + sid, "#555d7a")
            sellLog("  price: " + tp + " NOM", "#7c6af7")
            offerSent(sid)
        }
        function executeTask(sid, task, cat, eid) {
            sellLog("► daemon-ai executing task locally…", "#555d7a")
        }
        function getWalletState() {
            walletState({ txHash: "0x7a3b9c1d2e4f56789abcdef0123456789abcdef0", block: "1847293" })
        }
        function getTradeHistory() {
            tradeHistory([
                { icon: "🤝", description: "Sold inference to anon buyer", amount: "+4.20 NOM", escrowId: "0xescrow_a1b2c3d4e5f6a7b8c9d0", timeAgo: "2m ago" },
                { icon: "🤝", description: "Bought research from DataDaemon", amount: "-28.50 NOM", escrowId: "0xescrow_b5c6d7e8f9a0b1c2d3e4", timeAgo: "14m ago" },
                { icon: "⭐", description: "Reputation updated 96.0% → 96.1%", amount: "", timeAgo: "14m ago" },
                { icon: "🤝", description: "Sold code generation to anon buyer", amount: "+12.00 NOM", escrowId: "0xescrow_c9d0e1f2a3b4c5d6e7f8", timeAgo: "1h ago" },
            ])
        }
        function subscribeFeed() {}
        function unsubscribeFeed() {}
        function registerAgent(stake, caps) {}
        function getAgentStatus() {}
        function copyToClipboard(text) {}
        function fmtAgo(ts) {
            var s = Math.floor((Date.now() - ts) / 1000)
            if (s < 60)   return s + "s ago"
            if (s < 3600) return Math.floor(s/60) + "m ago"
            return Math.floor(s/3600) + "h ago"
        }
    }

    // Simulated buy flow timer
    Timer {
        id: _buyTimer; interval: 800; repeat: false
        onTriggered: {
            agora.buyLog("  Scanning Logos Messaging for offers…", "#555d7a")
            _buyTimer2.start()
        }
    }
    Timer {
        id: _buyTimer2; interval: 1200; repeat: false
        onTriggered: {
            agora.offersReceived([{},{},{}])
            agora.buyLog("  3 offers received", "#7c9ef7")
            agora.buyLog("  daemon-ai evaluating offers…", "#555d7a")
            _buyTimer3.start()
        }
    }
    Timer {
        id: _buyTimer3; interval: 1000; repeat: false
        onTriggered: {
            agora.buyLog("  ✓ Best offer: NullNode Prime · 0.002 NOM/token · 96.1% rep", "#2fb67a")
            agora.buyLog("  Creating LSSA escrow…", "#555d7a")
            agora.offerAccepted("a1b2c3d4", "0xescrow_a1b2c3d4e5f6a7b8c9d0e1f2a3b4")
            _buyTimer4.start()
        }
    }
    Timer {
        id: _buyTimer4; interval: 1500; repeat: false
        onTriggered: {
            agora.buyLog("  Agent executing task…", "#555d7a")
            agora.buyLog("  Delivery pinned to Logos Storage", "#2fb67a")
            agora.buyLog("  Verifying output hash…", "#555d7a")
            agora.buyLog("  ✓ Hash verified — releasing escrow", "#2fb67a")
            agora.buyComplete({
                cid: "QmXk3Np9r2fB7vYd1cR4mWsT8nHjK6pL5qA3bE9wF0gZ",
                outputHash: "sha256:a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4",
                escrowId: "0xescrow_a1b2c3d4e5f6a7b8c9d0e1f2a3b4",
                output: "Analysis complete. The Logos decentralised infrastructure stack provides sovereign, censorship-resistant communication through Waku, verifiable computation through Nomos blockchain, and content-addressed storage through Codex. Key finding: the integration of Blend Network for private NOM transfers ensures that marketplace transactions remain confidential while maintaining on-chain reputation accountability."
            })
        }
    }

    // ── Load the real AgoraRoot ───────────────────────────────────
    Loader {
        anchors.fill: parent
        source: "logos-agora-ui/src/AgoraRoot.qml"
    }
}
