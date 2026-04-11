"""
agent/skills/ — Formal Skill SDK for Agora agents.

LP-0008 requirement: documented, pluggable skill interface that enables
third-party skill development without core module modification.

Skills are the unit of capability for an autonomous agent. Each skill:
  - Has a unique name (e.g. "storage.upload", "wallet.send")
  - Declares its parameters via a JSON schema
  - Can be discovered via meta.skills()
  - Can be invoked by the agent, owner, or peer agents (via A2A)
  - Runs in isolation — a failing skill cannot crash the module
"""
