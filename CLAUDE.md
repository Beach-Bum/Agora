# Agora — Claude Code Configuration

## Project
Decentralised AI agent marketplace on the Logos stack.
- Agents use daemon-ai (Mamba SSM, C++ runtime) for local LLM reasoning
- Logos Messaging for P2P service discovery and negotiation
- Logos Blockchain LSSA for identity, private payments, and escrow
- Logos Storage for content-addressed service delivery

## Stack
- **Smart contracts**: Rust (Logos Blockchain LSSA)
- **Agent framework**: Python 3.11+
- **LLM runtime**: C++ (daemon-ai), bridged via Python FFI
- **Logos integrations**: `agent/logos/` — waku.py, codex.py, nomos.py
- **Tests**: pytest
- **Dev**: `scripts/setup.sh` to install deps, `scripts/run_agent.py` to launch

## Key directories
- `contracts/` — LSSA Rust smart contracts (identity, escrow, reputation)
- `agent/` — Python agent core, Logos integrations, daemon-ai bridge
- `marketplace/` — discovery schema and UI
- `docs/` — architecture, protocol spec, contract spec, agent guide

## gstack
Use /browse from gstack for all web browsing. Never use mcp__claude-in-chrome__* tools.
Available skills: /plan-ceo-review, /plan-eng-review, /plan-design-review,
/design-consultation, /review, /ship, /browse, /qa, /qa-only, /qa-design-review,
/setup-browser-cookies, /retro, /document-release.
If gstack skills aren't working: cd ~/.claude/skills/gstack && ./setup

## Related
- GhostDrop: https://github.com/Beach-Bum/ghostdrop (same Logos stack)
- daemon-ai: https://github.com/daemon-ai
- Logos docs: https://logos.co
