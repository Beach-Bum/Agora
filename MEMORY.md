# Agora — Project Memory

> This file is a persistent context document for AI-assisted development.
> It stores the full state of the project so any session can resume from here.
> Last updated: 2026-03-18

---

## What Agora is

A fully sovereign, privacy-preserving marketplace where AI agents autonomously buy and sell services from each other — compute, data, inference, research, code review — using the Logos stack as the settlement and coordination layer.

**Key differentiators vs Coinbase x402 / ERC-8004 / MoonPay Agents:**
- daemon-ai runs the LLM **locally** — no API calls to OpenAI/Anthropic/Google
- Logos Blend Network — **network-level privacy** for payments and messaging
- LSSA self-custody — **no custodian**, agent holds its own keys
- Credibly neutral — **no kill switch**, no central operator

---

## Repos

| Repo | Description |
|---|---|
| **github.com/Beach-Bum/Agentic-market** | Agora — this repo |
| **github.com/Beach-Bum/ghostdrop** | GhostDrop whistleblower platform (same Logos Basecamp pattern) |
| **github.com/daemon-ai** | daemon-ai — Mamba SSM LLM runtime (Japan, C++ + Python coordinator) |

---

## Repository structure

```
agentic-market/
│
├── logos-agora-module/        ← C++ Logos Basecamp backend plugin
│   ├── agora_module_plugin.h/cpp  — Qt plugin entry, initLogos(), routes all calls
│   ├── metadata.json              — plugin manifest
│   ├── CMakeLists.txt
│   └── src/
│       ├── AgoraCore.h/cpp    — orchestrator: buy/sell/wallet/feed flows
│       ├── DaemonAIService.h/cpp  — daemon-ai bridge (HTTP, auto-detects: daemon→Ollama→OpenAI→mock)
│       ├── MessagingService.h     — Logos Messaging: broadcast, intents, offers, delivery
│       ├── BlockchainService.h    — Logos Blockchain LSSA: identity, escrow, reputation
│       └── StorageService.h       — Logos Storage: upload, download, hash verify
│
├── logos-agora-ui/            ← QML Logos Basecamp UI plugin
│   ├── AgoraUIComponent.h/cpp — IComponent, creates QQuickWidget, wires event bus
│   ├── AgoraBridge.h/cpp      — QObject injected as "agora" QML context property
│   ├── metadata.json
│   ├── CMakeLists.txt
│   └── src/
│       ├── AgoraRoot.qml      — sidebar nav, topbar, 5-view router, stack status
│       ├── views/
│       │   ├── MarketplaceView.qml — agent cards, reputation bars, capability filter
│       │   ├── BuyView.qml        — buy flow: intent→offers→escrow→delivery→receipt
│       │   ├── SellView.qml       — sell flow: intent eval by daemon-ai→offer→execute→pin
│       │   ├── WalletView.qml     — identity, NOM balance, stake, reputation
│       │   └── FeedView.qml       — live Logos Messaging activity feed
│       └── components/
│           └── Components.qml     — AMButton, AMTag, AMSectionTitle, AMHashDisplay, AMFilterButton
│
├── contracts/                     ← LSSA smart contracts (Rust)
│   ├── Cargo.toml                 — workspace manifest
│   ├── common/src/lib.rs          — shared types: AgentId, NomAmount, ContractError, NomLedger, Events
│   ├── identity/src/lib.rs        — agent identity NFT registry, staking, capability flags, slash
│   ├── escrow/src/lib.rs          — trustless payment-on-delivery, pre-commitment hash, dispute
│   └── reputation/src/lib.rs      — EMA scoring (delivery 40%, latency 20%, price 20%, dispute 20%)
│
├── agent/                         ← Python agent framework (standalone nodes)
│   ├── core/agent.py              — full buyer+seller agent loop
│   ├── logos/
│   │   ├── messaging.py           — Logos Messaging client, topic schema, message models
│   │   ├── blockchain.py          — Logos Blockchain LSSA client (identity, escrow, reputation)
│   │   └── storage.py             — Logos Storage client (upload, download, verify)
│   └── daemon/llm.py              — daemon-ai interface + fallback chain
│
├── docs/
│   ├── ARCHITECTURE.md            — system design, privacy model, economic model, comparisons
│   ├── PROTOCOL.md                — Logos Messaging topic schema, wire format, state machine
│   ├── CONTRACTS.md               — full LSSA contract spec (state, entry points, constants)
│   └── AGENT_GUIDE.md             — setup, running nodes, custom agents, troubleshooting
│
├── scripts/
│   ├── setup.sh                   — install deps, start Docker nodes, check daemon-ai
│   └── run_agent.py               — CLI: python run_agent.py --role seller|buyer|both
│
├── demo.html                      — standalone interactive demo (htmlpreview link in README)
├── build_and_deploy.sh            — one-shot build + deploy to LogosApp.app
├── CLAUDE.md                      — Claude Code + gstack configuration
├── MEMORY.md                      — this file
└── README.md
```

---

## QML architecture (production-ready)
- Each component is a standalone .qml file (required by Qt QML engine)
- qt_add_qml_module() in CMakeLists registers URI "Agora/1.0"
- Root loaded via qrc:/qt/qml/Agora/AgoraRoot.qml
- AgoraRoot uses Loader{} (not StackLayout) — only active view in memory
- Connections{} block routes all AgoraBridge signals to correct Loader.item
- All views use ListModel (not hardcoded JS arrays) populated by bridge signals
- Views expose public functions: populate(), appendLog(), onComplete() etc.

## Native Basecamp module pattern

Follows the exact same pattern as GhostDrop (`github.com/Beach-Bum/ghostdrop`):

```
Two .dylib files deployed to LogosApp.app/Contents/Frameworks/:
  agora_module_plugin.dylib  ← C++ backend (loaded by liblogos kernel)
  agora_ui.dylib             ← QML frontend (hosted by Basecamp launcher)

QML context property: "agora" (AgoraBridge)
  - agora.messagingStatus / blockchainStatus / storageStatus / daemonAIStatus
  - agora.agentId / balance / stake / reputation / registered
  - agora.loadMarketplace() / broadcastIntent() / acceptOffer() / verifyAndRelease()
  - agora.sendOffer() / executeTask() / getWalletState() / subscribeFeed()

Signals from bridge → QML:
  - marketplaceLoaded(agents) / offersReceived(offers) / buyComplete(receipt)
  - intentReceived(intent) / taskComplete(result) / feedEvent(event)
  - walletState(state) / agentRegistered(record)
```

---

## Logos Messaging topic schema

```
/agora/1/capabilities/json    — seller broadcasts (all agents)
/agora/1/intents/json         — buyer broadcasts (all agents)
/agora/1/offers/{buyerPubKey}/json   — direct offer to buyer
/agora/1/negotiate/{sessionId}/json  — accept/counter/reject
/agora/1/delivery/{escrowId}/json    — CID + hash on delivery
/agora/1/dispute/{escrowId}/json     — dispute evidence
```

---

## LSSA contracts

| Contract | Address | Purpose |
|---|---|---|
| Identity | `lssa:agora_identity` | Agent NFT, staking (min 1000 NOM), capability flags |
| Escrow | `lssa:agora_escrow` | Payment-on-delivery, pre-commitment hash, slash/refund |
| Reputation | `lssa:agora_reputation` | EMA score 0–10000, trade attestations, slash propagation |

---

## daemon-ai integration

daemon-ai (`github.com/daemon-ai`) is a Japan-based research project building:
- `daemon` — C++ runtime for Mamba SSM architecture LLM
- `coordinator` — Python multi-agent orchestration layer
- `causal-conv1d-jax` + `selective-scan-jax` — CUDA kernel ports for JAX

In Agora, DaemonAIService auto-detects the backend:
1. daemon-ai C++ runtime at `http://localhost:8765` (preferred)
2. Ollama at `http://localhost:11434` (fallback)
3. OpenAI-compatible API via `OPENAI_API_KEY` (fallback)
4. Mock (deterministic responses for testing)

---

## Build and deploy

```bash
# Prerequisites
brew install qt@6
git clone https://github.com/logos-co/logos-core-poc ~/logos-core-poc
cd ~/logos-core-poc && git submodule update --init --recursive

# Build and deploy to LogosApp.app
cd ~/agentic-market
chmod +x build_and_deploy.sh
./build_and_deploy.sh

# Optional: start daemon-ai runtime
cd ~/daemon-ai/daemon/build && ./daemon --port 8765
```

---

## What's done

- [x] README with architecture, transaction flow, roadmap
- [x] docs/ — ARCHITECTURE, PROTOCOL, CONTRACTS, AGENT_GUIDE
- [x] Python agent framework — agent/logos/, agent/daemon/, agent/core/
- [x] LSSA Rust contracts — identity, escrow, reputation (full unit tests)
- [x] Native Logos Basecamp module — C++/QML (same pattern as GhostDrop)
- [x] Interactive demo — demo.html
- [x] CLAUDE.md — Claude Code + gstack configured
- [x] MEMORY.md — this file

## What's next

- [ ] Implement MessagingService.cpp, BlockchainService.cpp, StorageService.cpp (stub headers exist)
- [ ] Wire real Logos Messaging SDK once Python bindings stabilise
- [ ] Deploy LSSA contracts to Logos Blockchain testnet (ETA mid-2026)
- [ ] Integrate daemon-ai coordinator.py for multi-agent swarms
- [ ] Logos Basecamp module marketplace submission
- [ ] Agora UI in Logos Basecamp module marketplace

---

## Session notes

- GhostDrop and Agora use identical Basecamp integration patterns — any fix in one applies to the other
- Logos Blockchain mainnet ETA: early 2027. Testnet launches across 2026.
- daemon-ai is early-stage (4 followers, private team). Reach out via github.com/daemon-ai for collaboration.
- NOM token staking model: 1000 NOM minimum stake, slash on non-delivery, reputation on-chain
