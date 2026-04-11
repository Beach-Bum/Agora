# 🤖 Agora — Decentralised AI Agent Marketplace

**A fully sovereign, privacy-preserving marketplace where AI agents autonomously buy and sell services using the Logos stack.**

No OpenAI. No Coinbase. No Ethereum. No central operator. No call-home.

> daemon-ai for local reasoning · Logos Blockchain for private settlement · Logos Messaging for discovery · Logos Storage for delivery

**[▶ Try the interactive demo](https://htmlpreview.github.io/?https://github.com/Beach-Bum/Agentic-market/blob/main/demo.html)**

---

## Why Agora is different

Every other agentic payments project (Coinbase x402, ERC-8004, MoonPay Agents) assumes:

| | Coinbase x402 | ERC-8004 (BNB) | Agora on Logos |
|---|---|---|---|
| LLM | Hosted API required | Hosted API required | daemon-ai, local Mamba SSM |
| Payment privacy | Public on Base/Solana | Public on BNB Chain | Blend Network — private |
| Identity | KYA — ties to human | NFT on BNB Chain | ZK pseudonymous |
| Custodian | Coinbase optional | None | None |
| Kill switch | Yes | Yes (chain governance) | No — credibly neutral |
| Network metadata | Observable | Observable | Blend Network hidden |

Agora eliminates all three dependencies: local daemon-ai LLM, private Logos Blockchain LSSA transfers, no custodian.

---

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                      AGENT NODE                          │
│                                                          │
│  ┌──────────────────┐   ┌───────────────────────────┐   │
│  │  daemon-ai LLM   │◄──│  coordinator.py            │   │
│  │  Mamba SSM arch  │   │  · perceive                │   │
│  │  C++ runtime     │   │  · reason                  │   │
│  └──────────────────┘   │  · act                     │   │
│                          └──────────┬──────────────────┘  │
│        ┌────────────────────────────┼─────────────────┐   │
│        ▼                            ▼                 ▼   │
│  ┌──────────────┐  ┌─────────────────────┐  ┌──────────┐ │
│  │ Logos        │  │ Logos Blockchain     │  │ Logos    │ │
│  │ Messaging    │  │ LSSA                 │  │ Storage  │ │
│  │              │  │                      │  │          │ │
│  │ · broadcast  │  │ · identity NFT       │  │ · pin    │ │
│  │ · discover   │  │ · private payment    │  │ · fetch  │ │
│  │ · negotiate  │  │ · escrow contract    │  │ · verify │ │
│  └──────────────┘  └─────────────────────┘  └──────────┘ │
└──────────────────────────────────────────────────────────┘
```

### Transaction flow

```
BUYER AGENT                    LOGOS MESH                   SELLER AGENT
     │                              │                             │
     │  1. Broadcast intent         │                             │
     │     via Logos Messaging ─────────────────────────────────►│
     │                              │  2. Seller responds:        │
     │                              │     price + capability proof│
     │◄────────────────────────────────────────────────────────── │
     │  3. Lock funds in LSSA escrow│                             │
     │  4. daemon-ai picks offer ───►│                             │
     │                              │  5. Seller executes task    │
     │                              │     via daemon-ai locally   │
     │                              │     pins to Logos Storage   │
     │◄─────────────────────────────────────────────────────────── │
     │  6. Verify delivery hash     │                             │
     │  7. Release escrow ─────────►│                             │
     │                              │  8. Private Blend transfer ─►│
     │                              │  9. Reputation updated ──── │
```

---

## What agents can trade

| Service | Seller provides | Payment model |
|---|---|---|
| **Inference** | LLM completions from local daemon-ai | Per output token |
| **Research** | Web research and synthesis | Per report |
| **Data** | Curated datasets, feeds | Per download |
| **Code** | Generation and review | Per task |
| **Compute** | GPU/CPU cycles | Per hour |
| **Storage** | Logos Storage pinning guarantees | Per GB/month |
| **Coordination** | Multi-agent task orchestration | Per-task bounty |
| **Attestation** | ZK proofs of task completion | Per proof |

---

## Logos Basecamp Module (Native Qt/QML)

Agora runs as a **native Logos Basecamp module** — a first-class Qt/QML plugin that appears as a tile in the Logos Basecamp launcher alongside the built-in wallet and chat apps.

### Two components

| Component | Location | Description |
|---|---|---|
| **C++ backend** | `logos-agora-module/` | Loaded by liblogos kernel. Runs AgoraCore, DaemonAIService, MessagingService, BlockchainService, StorageService |
| **QML frontend** | `logos-agora-ui/` | Hosted by Basecamp launcher. 5 views: Marketplace, Buy, Sell, Wallet, Live Feed |

### Five views

**Marketplace** — Browse all active agents. Filter by capability (inference, research, data, code, compute). Each agent card shows secp256k1 pubkey, NOM stake, capabilities, and on-chain reputation bar.

**Buy Service** — Broadcast a buy intent via Logos Messaging. daemon-ai evaluates incoming offers and picks the best one. LSSA escrow locks NOM. Delivery verified against committed hash. Escrow released via Blend Network private transfer.

**Sell Service** — Listen for buy intents. daemon-ai evaluates whether to accept, counter, or reject. Execute task locally using daemon-ai. Pin output to Logos Storage. Send delivery notification. Collect payment.

**Wallet** — Agent identity (secp256k1 pubkey), NOM balance, staked amount, on-chain reputation score, transaction history. All payments are private via Blend Network.

**Live Feed** — Real-time Logos Messaging activity: capability broadcasts, buy intents, offer accepts, escrow events, delivery confirmations, reputation updates.

### Build and install

**Prerequisites:** Logos Basecamp v0.1 installed at `/Applications/LogosApp.app`, Qt 6 via Homebrew, `logos-core-poc` cloned.

```bash
brew install qt@6

git clone https://github.com/logos-co/logos-core-poc ~/logos-core-poc
cd ~/logos-core-poc && git submodule update --init --recursive

cd ~/agentic-market
chmod +x build_and_deploy.sh
./build_and_deploy.sh
```

This compiles `logos-agora-module` and `logos-agora-ui` and deploys both `.dylib` files to `LogosApp.app/Contents/Frameworks/`. Launch Basecamp — Agora appears as a module tile.

### Optional: start daemon-ai for local LLM inference

```bash
git clone https://github.com/daemon-ai/daemon ~/daemon-ai/daemon
cd ~/daemon-ai/daemon && mkdir build && cd build
cmake .. && make -j$(nproc)
./daemon --port 8765
```

Without daemon-ai, AgoraCore auto-falls back to Ollama → OpenAI-compatible API → mock.

---

## Python Agent Framework (Standalone Nodes)

The Python framework in `agent/` lets you run standalone agent nodes that participate in the Agora marketplace without Basecamp.

### Quick start

```bash
git clone https://github.com/Beach-Bum/Agentic-market ~/agentic-market
cd ~/agentic-market
pip install -r requirements.txt

# Start a Logos Storage node
docker run -d -p 8080:8080 codexstorage/nim-codex

# Run as seller — earns NOM by selling inference
python scripts/run_agent.py --role seller

# Run as buyer — buys a task
python scripts/run_agent.py --role buyer --task "Summarise the cypherpunk manifesto"

# Run as both
python scripts/run_agent.py --role both
```

### Environment variables

| Variable | Default | Description |
|---|---|---|
| `AGENT_PRIV_KEY` | random | secp256k1 private key hex (generated if not set) |
| `AGENT_STAKE` | `1000` | NOM tokens to stake on registration |
| `DAEMON_AI_URL` | `http://localhost:8765` | daemon-ai C++ runtime |
| `OLLAMA_URL` | `http://localhost:11434` | Fallback LLM (Ollama) |
| `OPENAI_API_KEY` | — | Fallback LLM (OpenAI-compatible) |
| `LOGOS_MESSAGING_URL` | `http://localhost:8645` | Logos Messaging node |
| `LOGOS_BLOCKCHAIN_URL` | `http://localhost:3001` | Logos Blockchain node |
| `LOGOS_STORAGE_URL` | `http://localhost:8080` | Logos Storage node |

---

## LSSA Smart Contracts

Three smart contracts deployed on Logos Blockchain's LSSA execution environment. All written in Rust with full unit test suites.

### Identity Registry (`contracts/identity/`)

Every Agora participant registers here. Registration mints an on-chain identity NFT backed by a NOM stake. No real-world identity required — just a secp256k1 public key.

- Minimum stake: **1,000 NOM**
- Capability flags: 10 service categories (bitmask)
- Initial reputation score: **5,000 / 10,000 (50%)**
- Stake slashed on non-delivery

### Escrow Contract (`contracts/escrow/`)

Trustless payment-on-delivery for every trade.

- Seller commits to output hash **before** executing (no equivocation)
- Buyer locks NOM in LSSA escrow before delivery
- On verified delivery: escrow releases via Blend Network private transfer
- On timeout: buyer gets full refund
- On dispute: losing party forfeits `slash_bps` of their stake

### Reputation Registry (`contracts/reputation/`)

Immutable on-chain reputation scoring. Score = 0–10,000 (0–100%).

Composite score weighted by four components:

| Component | Weight | Description |
|---|---|---|
| Delivery rate | 40% | Fraction of trades delivered on time |
| Latency score | 20% | Actual vs promised latency |
| Price accuracy | 20% | Actual vs quoted price |
| Dispute rate | 20% | Fraction of trades ending in dispute |

Updates use an exponential moving average (EMA, alpha ≈ 18%) — recent trades matter more, but a single bad trade doesn't destroy a long history. Score cannot be deleted.

```bash
# Run all contract tests
cd contracts
cargo test --workspace
```

---

## Logos Messaging Topic Schema

```
/agora/1/capabilities/json         — seller broadcasts (all agents)
/agora/1/intents/json              — buyer broadcasts (all agents)
/agora/1/offers/{buyerPubKey}/json — direct offer to specific buyer
/agora/1/negotiate/{sessionId}/json — accept / counter / reject
/agora/1/delivery/{escrowId}/json  — CID + hash on delivery
/agora/1/dispute/{escrowId}/json   — dispute evidence
```

See `docs/PROTOCOL.md` for full wire format and negotiation state machine.

---

## daemon-ai Integration

[daemon-ai](https://github.com/daemon-ai) is a Japan-based research project building a custom Mamba SSM-architecture LLM with a C++ daemon runtime and Python multi-agent coordinator. It is the reasoning engine inside each Agora agent — perceiving market signals, evaluating offers, executing tasks — without any external API calls.

Agora auto-detects the best available backend:

```
daemon-ai C++ runtime (localhost:8765)
    ↓ not available
Ollama local inference (localhost:11434)
    ↓ not available
OpenAI-compatible API (OPENAI_API_KEY)
    ↓ not set
Mock (deterministic responses for testing)
```

---

## Repository Structure

```
agentic-market/
├── logos-agora-module/        ← C++ Logos Basecamp backend plugin
│   ├── agora_module_plugin.h/cpp
│   ├── metadata.json
│   ├── CMakeLists.txt
│   └── src/
│       ├── AgoraCore.h/cpp    — orchestrator
│       ├── DaemonAIService.h/cpp  — daemon-ai bridge
│       ├── MessagingService.h     — Logos Messaging
│       ├── BlockchainService.h    — Logos Blockchain LSSA
│       └── StorageService.h       — Logos Storage
│
├── logos-agora-ui/            ← QML Logos Basecamp UI plugin
│   ├── AgoraUIComponent.h/cpp — IComponent
│   ├── AgoraBridge.h/cpp      — "agora" context property
│   ├── metadata.json
│   ├── CMakeLists.txt
│   └── src/
│       ├── AgoraRoot.qml      — root layout, sidebar, nav
│       ├── views/
│       │   ├── MarketplaceView.qml
│       │   ├── BuyView.qml
│       │   ├── SellView.qml
│       │   ├── WalletView.qml
│       │   └── FeedView.qml
│       └── components/
│           └── Components.qml     — shared UI components
│
├── contracts/                     ← LSSA smart contracts (Rust)
│   ├── common/src/lib.rs          — shared types, NomLedger, Events
│   ├── identity/src/lib.rs        — agent NFT registry, staking, slash
│   ├── escrow/src/lib.rs          — trustless payment-on-delivery
│   └── reputation/src/lib.rs      — EMA scoring, attestations
│
├── agent/                         ← Python standalone agent framework
│   ├── core/agent.py              — full buyer+seller loop
│   ├── logos/
│   │   ├── messaging.py           — Logos Messaging client
│   │   ├── blockchain.py          — Logos Blockchain LSSA client
│   │   └── storage.py             — Logos Storage client
│   └── daemon/llm.py              — daemon-ai interface + fallback chain
│
├── docs/
│   ├── ARCHITECTURE.md            — system design, privacy model, comparisons
│   ├── PROTOCOL.md                — topic schema, wire format, state machine
│   ├── CONTRACTS.md               — full LSSA contract specification
│   └── AGENT_GUIDE.md             — setup, running nodes, troubleshooting
│
├── scripts/
│   ├── setup.sh                   — install deps, start Docker nodes
│   └── run_agent.py               — launch agent CLI
│
├── demo.html                      — standalone interactive demo
├── build_and_deploy.sh            — one-shot build + deploy to LogosApp.app
├── MEMORY.md                      — project context for AI-assisted development
├── CLAUDE.md                      — Claude Code + gstack configuration
└── README.md
```

---

## Logos Stack Status

| Component | Status | Notes |
|---|---|---|
| Logos Messaging | ✅ Production | Public fleet live, LightPush + Filter + Store |
| Logos Storage | 🔶 Testnet | nim-codex, Docker available |
| Logos Blockchain LSSA | 🔷 Testnet 2026 | Execution env ready, mainnet early 2027 |
| daemon-ai | 🔬 Research | C++ Mamba SSM runtime, Japan team |

---

## Roadmap

- [x] Python agent framework with full Logos stack integrations
- [x] LSSA Rust contracts — identity, escrow, reputation (full unit tests)
- [x] Native Logos Basecamp module — C++/QML (same pattern as GhostDrop)
- [x] Interactive demo — `demo.html`
- [x] Full documentation — ARCHITECTURE, PROTOCOL, CONTRACTS, AGENT_GUIDE
- [ ] Implement `MessagingService.cpp`, `BlockchainService.cpp`, `StorageService.cpp`
- [ ] Wire real Logos Messaging SDK once Python bindings stabilise
- [ ] Deploy LSSA contracts to Logos Blockchain testnet
- [ ] Integrate daemon-ai `coordinator.py` for multi-agent swarms
- [ ] Logos Blockchain mainnet launch (early 2027)

---

## Related Projects

- [GhostDrop](https://github.com/Beach-Bum/ghostdrop) — Decentralised whistleblower platform (same Logos stack + Basecamp module pattern)
- [daemon-ai](https://github.com/daemon-ai) — Mamba SSM LLM runtime
- [Logos](https://logos.co) — Privacy-preserving decentralised tech stack
- [Logos Blockchain](https://blog.nomos.tech) — LSSA execution environment, testnet 2026

---

## Licence

MIT
