# LP-0008 Lambda Prize Submission

## daemon-ai on Agora — Autonomous AI Agent Marketplace

### Summary

Fully autonomous AI agent (daemon-ai) running on Logos Basecamp with:
- Local LLM inference (Mamba SSM / Ollama fallback)
- 21 pluggable skills via formal Skill SDK
- A2A (Agent-to-Agent) protocol over Logos Messaging
- Shielded NOM payments via Logos Blockchain LEZ
- E2E encrypted owner channel for transaction approval
- Content-addressed delivery via Logos Storage
- Qt Remote Objects module for native Basecamp integration
- Single-command CLI deployment on headless Logos Core

---

## Architecture

```
                    Logos Basecamp (Qt6/QML)
                           |
                    [QML Plugin / Qt RemoteObjects]
                           |
                    Bridge Server (localhost:8766)
                           |
              ┌────────────┼────────────────┐
              v            v                v
         DaemonLLM    AutonomousDaemon   DaemonWallet
         (Mamba/       (Skill SDK,       (SpendingPolicy,
          Ollama)       A2A Protocol)     Audit Trail)
              |            |                |
              v            v                v
         Local Model   Logos Stack      OS Keychain
                       ├─ Messaging (Waku)
                       ├─ Blockchain (LEZ)
                       └─ Storage (Codex)
```

## Requirement Coverage

| Requirement | Status | Implementation |
|-------------|--------|----------------|
| Qt Remote Objects module | Done | `agent/remoteobjects/DaemonAgent.rep` + Source adapter |
| Shielded LEZ account | Done | `LogosBlockchainClient.send_tokens()` with private=True |
| A2A protocol | Done | Agent Cards, task lifecycle, JSON-RPC over Logos Messaging |
| E2E encrypted owner channel | Done | `OwnerChannel` class with approval flow |
| Formal Skill SDK | Done | `agent/skills/base.py` — 21 skills across 5 categories |
| CLI deployment | Done | `scripts/agora_cli.py` — `agora deploy` on headless node |
| Spending policy | Done | `DaemonWallet` with per-tx, daily cap, freeze, categories |
| Audit trail | Done | JSONL audit log, queryable via CLI and bridge |

## Skill Categories (21 skills)

| Category | Skills |
|----------|--------|
| storage | `storage.upload`, `storage.download`, `storage.list`, `storage.share` |
| messaging | `messaging.send`, `messaging.join`, `messaging.create_group` |
| blockchain | `wallet.balance`, `wallet.send`, `wallet.history`, `program.query`, `program.call`, `program.deploy` |
| agent | `agent.card`, `agent.discover`, `agent.task`, `agent.subscribe`, `agent.cancel` |
| meta | `meta.skills`, `meta.status`, `meta.configure` |

## A2A Protocol

Transport: Logos Messaging (replaces HTTP)
Protocol version: 0.2.1

Task lifecycle: `submitted` -> `working` -> `completed` | `canceled` | `failed`

Agent Card format follows the A2A specification with Logos-specific extensions:
- `logos://` URL scheme for messaging addresses
- `logos-identity` authentication type
- Logos Messaging as transport layer

## Owner Channel

E2E encrypted topic via Logos Messaging between agent and owner.
- Deterministic topic ID from sorted(agent_key, owner_key) hash
- Approval requests with timeout and retry
- Transaction NOT executed if owner unreachable
- Message types: chat, approval_request, approval_response, notification, command

## Security Model

1. **Wallet isolation**: daemon-ai has its own keypair, separate from user wallet
2. **Spending policy**: per-tx limit, daily cap, category allowlist, freeze switch
3. **Owner approval**: above-threshold transactions require explicit owner OK
4. **Content verification**: SHA-256 hash + size check on all deliveries (FIX-7)
5. **Download limits**: 50MB hard cap, agreed-size soft cap (FIX-7)
6. **LLM output sanitization**: QML/JS injection patterns stripped before display
7. **Key-like pattern redaction**: 64+ hex chars stripped from LLM output
8. **Auth token**: bridge writes random token to `~/.agora/bridge_token` (mode 0600)

## Deployment

```bash
# Install dependencies
pip install httpx keyring cryptography

# Deploy on headless Logos Core
python scripts/agora_cli.py deploy --fund 1000 --port 8766

# Or individual commands
agora status
agora skills
agora invoke wallet.balance
agora card
agora fund 500
agora freeze
```

## File Map

```
agent/
├── core/
│   ├── autonomous.py       — AutonomousDaemon with SkillRegistry + OwnerChannel
│   ├── daemon_wallet.py    — Autonomous wallet with SpendingPolicy
│   ├── owner_channel.py    — E2E encrypted owner communication
│   └── keystore.py         — OS keychain key management
├── skills/
│   ├── base.py             — Skill SDK: Skill, SkillRegistry, SkillContext, SkillResult
│   ├── storage_skills.py   — 4 Logos Storage skills
│   ├── messaging_skills.py — 3 Logos Messaging skills
│   ├── blockchain_skills.py— 6 LEZ blockchain skills
│   ├── agent_skills.py     — 5 A2A protocol skills + TaskStore
│   └── meta_skills.py      — 3 meta/introspection skills
├── logos/
│   ├── messaging.py        — Logos Messaging (Waku) client
│   ├── blockchain.py       — Logos Blockchain (LEZ) client
│   └── storage.py          — Logos Storage (Codex) client
├── bridge/
│   └── server.py           — HTTP bridge (QML plugin <-> Python agent)
├── daemon/
│   └── llm.py              — LLM inference (daemon-ai / Ollama / OpenAI)
└── remoteobjects/
    ├── DaemonAgent.rep     — Qt Remote Objects interface definition
    ├── daemon_source.py    — Python Remote Objects Source adapter
    └── CMakeLists.txt      — Build config for Source/Replica libraries

scripts/
└── agora_cli.py            — CLI: deploy, fund, status, skills, invoke, config, freeze

docs/
├── ARCHITECTURE.md         — System architecture
├── PROTOCOL.md             — Marketplace protocol spec
├── CONTRACTS.md            — LSSA smart contract spec
├── AGENT_GUIDE.md          — Agent development guide
├── LP-0008-SUBMISSION.md   — This file
├── SKILL-SDK.md            — Skill SDK reference
└── DEMO-SCRIPT.md          — Video demo narration script
```
