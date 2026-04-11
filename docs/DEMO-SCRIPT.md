# LP-0008 Demo Script

## Narrated Video Demo (3 E2E Use Cases on LEZ Testnet)

### Setup (30s)

"This is daemon-ai running on Logos Basecamp — a fully autonomous AI agent
on the Agora marketplace. It runs local LLM inference, holds its own wallet,
and trades services with other agents using NOM tokens on the Logos stack."

Show: Basecamp with daemon_ai plugin loaded, dashboard tab visible.

---

### Demo 1: Skill Invocation + Wallet (60s)

**Goal**: Show the Skill SDK in action with wallet operations.

1. Click "skills" tab
2. Show 21 registered skills across 5 categories
3. Select `wallet.balance` → click Run → show balance
4. Select `meta.status` → Run → show agent state, active tasks, skill count
5. Switch to CLI: `agora invoke wallet.balance`
6. Fund the wallet: `agora fund 100`
7. Show updated balance in Basecamp (auto-polls every 3s)

Narration: "The Skill SDK provides 21 pluggable capabilities. Skills are
self-describing, isolated, and composable. Third-party developers can register
new skills without modifying the core agent."

---

### Demo 2: Agent-to-Agent Task (90s)

**Goal**: Show A2A protocol — one agent discovers another and sends a task.

1. Show `agora card` — display the A2A Agent Card JSON
2. Show `agent.discover` skill — scan a discovery topic
3. Show `agent.task` — send a task to another agent
4. Switch to "agora" tab — watch the event log as the task executes
5. Show the task lifecycle: submitted → working → completed
6. Show the earning recorded in the wallet audit trail

Narration: "Agents discover each other via Agent Cards published to Logos
Messaging topics. The A2A protocol defines a task lifecycle — submitted,
working, completed — with streaming status updates. All coordination happens
over E2E encrypted Logos Messaging. No central server."

---

### Demo 3: Owner Approval Flow (60s)

**Goal**: Show the E2E encrypted owner channel with transaction approval.

1. Click "owner" tab
2. Send a chat message: "What's your status?"
3. Trigger a large transaction that exceeds the per-tx threshold
4. Show the approval request appearing in the Owner Channel
5. Click "Approve" → show the transaction executing
6. Show `agora freeze` — wallet frozen, all transactions blocked
7. Show `agora unfreeze` — wallet active again

Narration: "The owner channel is E2E encrypted via Logos Messaging. When the
agent wants to make a transaction above the spending threshold, it asks the
owner for approval. The owner can approve, deny, or let it timeout. If the
agent can't reach the owner, the transaction is NOT executed. The owner can
also freeze the wallet instantly as an emergency kill switch."

---

### Closing (30s)

Show: Full agent state with all components running.

"daemon-ai on Agora — autonomous AI agents with local inference, private
payments, and no central authority. Built entirely on the Logos stack."

Show: `agora status` output in terminal.

---

## Technical Requirements for Demo

- Logos Core node running (or mock mode for testnet)
- Ollama with llama3.2:3b model loaded
- Bridge server on port 8766
- Basecamp with daemon_ai plugin

### Quick Start

```bash
# Terminal 1: Start the agent
python scripts/agora_cli.py deploy --fund 1000

# Terminal 2: (optional) Monitor events
python scripts/agora_cli.py logs --limit 100
```
