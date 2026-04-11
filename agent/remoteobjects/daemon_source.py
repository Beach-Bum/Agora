"""
agent/remoteobjects/daemon_source.py

Qt Remote Objects Source — exposes DaemonAgent as a Remote Object.

LP-0008: Enables Basecamp to connect to daemon-ai via Qt Remote Objects
instead of HTTP polling. The Source publishes state changes as signals
and processes slot calls from the Replica (Basecamp QML).

Architecture:
    DaemonAgentSource (this)  <--Qt RemoteObjects-->  DaemonAgentReplica (Basecamp)
            |
            v
    DaemonBridge (HTTP server)  -->  AutonomousDaemon  -->  Logos Stack

For QML-only plugins (current mode), the HTTP bridge is used directly.
For native Basecamp modules, this RemoteObjects source enables tighter integration.
"""

import json
import asyncio
from typing import Optional


class DaemonAgentSource:
    """
    Qt Remote Objects Source adapter for daemon-ai.

    Wraps the bridge's methods and exposes them as Qt Remote Object
    properties, slots, and signals. Used when daemon-ai is loaded
    as a native Basecamp module (not QML-only plugin).

    In QML-only mode, this is NOT used — the QML plugin talks to the
    HTTP bridge directly via XMLHttpRequest.
    """

    def __init__(self, bridge):
        self._bridge = bridge
        self._cache = {}

    # ── Properties (read-only, pushed to replicas) ──────────────

    @property
    def agentId(self) -> str:
        return self._bridge.wallet.pub_key_hex if self._bridge.wallet else ""

    @property
    def agentName(self) -> str:
        return self._bridge.daemon.config.agent_name

    @property
    def connected(self) -> bool:
        return self._bridge.backend in ("daemon", "ollama", "openai")

    @property
    def backend(self) -> str:
        return self._bridge.backend or "mock"

    @property
    def currentModel(self) -> str:
        return self._bridge.current_model

    @property
    def totalTokens(self) -> int:
        return self._bridge.total_tokens

    @property
    def daemonRunning(self) -> bool:
        return self._bridge.daemon._running

    @property
    def uptimeSeconds(self) -> int:
        import time
        return int(time.time() - self._bridge.start_time)

    @property
    def walletBalance(self) -> float:
        return self._bridge.wallet._balance_nom

    @property
    def walletAvailable(self) -> float:
        state = self._bridge.wallet.state()
        return state.get("available_nom", 0.0)

    @property
    def walletEarned(self) -> float:
        return self._bridge.wallet._earned_total

    @property
    def walletFrozen(self) -> bool:
        return self._bridge.wallet.policy.frozen

    @property
    def policyMaxPerTx(self) -> float:
        return self._bridge.wallet.policy.max_per_tx_nom

    @property
    def policyDailyCap(self) -> float:
        return self._bridge.wallet.policy.daily_cap_nom

    @property
    def tasksCompleted(self) -> int:
        return self._bridge.daemon.tasks_completed

    @property
    def tasksFailed(self) -> int:
        return self._bridge.daemon.tasks_failed

    @property
    def offersSent(self) -> int:
        return self._bridge.daemon.offers_sent

    @property
    def intentsEvaluated(self) -> int:
        return self._bridge.daemon.intents_evaluated

    @property
    def skillCount(self) -> int:
        if self._bridge.daemon.registry:
            return self._bridge.daemon.registry.count
        return 0

    # ── Slots (called by replicas) ──────────────────────────────

    def chat(self, message: str) -> str:
        result = self._bridge.chat(message)
        return json.dumps(result)

    def fundWallet(self, amount: float) -> str:
        result = self._bridge.wallet_fund(amount)
        return json.dumps(result)

    def freezeWallet(self) -> bool:
        self._bridge.wallet_freeze()
        return True

    def unfreezeWallet(self) -> bool:
        self._bridge.wallet_unfreeze()
        return True

    def updatePolicy(self, key: str, value: str) -> str:
        if key == "max_per_tx_nom":
            result = self._bridge.wallet_update_policy({"max_per_tx_nom": float(value)})
        elif key == "daily_cap_nom":
            result = self._bridge.wallet_update_policy({"daily_cap_nom": float(value)})
        else:
            result = {"error": f"unknown policy key: {key}"}
        return json.dumps(result)

    def listSkills(self, category: str = "") -> str:
        result = self._bridge.list_skills(category or None)
        return json.dumps(result)

    def invokeSkill(self, name: str, params_json: str) -> str:
        params = json.loads(params_json) if params_json else {}
        result = self._bridge.invoke_skill(name, params)
        return json.dumps(result)

    def ownerApprove(self, request_id: str) -> bool:
        result = self._bridge.owner_approve(request_id)
        return result.get("approved", False)

    def ownerDeny(self, request_id: str) -> bool:
        result = self._bridge.owner_deny(request_id)
        return result.get("denied", False)

    def ownerPending(self) -> str:
        result = self._bridge.owner_pending()
        return json.dumps(result)

    def ownerChat(self, message: str) -> bool:
        result = self._bridge.owner_chat(message)
        return result.get("sent", False)

    def agentCard(self) -> str:
        result = self._bridge.agent_card()
        return json.dumps(result)
