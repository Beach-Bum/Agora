"""
agent/skills/agent_skills.py

LP-0008 required A2A-compatible agent-to-agent coordination skills.

Skills:
  agent.card      — return A2A-compatible Agent Card
  agent.discover  — fetch Agent Cards from discovery topics
  agent.task      — send task request following A2A lifecycle
  agent.subscribe — subscribe to streaming status updates
  agent.cancel    — cancel in-progress task with refund
"""

import json
import time
import secrets
from typing import Optional

from agent.skills.base import Skill, SkillContext, SkillResult, SkillRegistry
from agent.logos.messaging import LogosMessagingClient


# ── A2A Protocol Data Structures ────────────────────────────────────

A2A_PROTOCOL_VERSION = "1.0.0"
A2A_TRANSPORT = "logos-messaging"

# A2A Task States (v1.0.0 spec — github.com/a2aproject/A2A)
TASK_SUBMITTED = "submitted"
TASK_WORKING = "working"
TASK_INPUT_REQUIRED = "input-required"
TASK_AUTH_REQUIRED = "auth-required"
TASK_COMPLETED = "completed"
TASK_FAILED = "failed"
TASK_CANCELED = "canceled"
TASK_REJECTED = "rejected"

VALID_TASK_STATES = {
    TASK_SUBMITTED, TASK_WORKING, TASK_INPUT_REQUIRED, TASK_AUTH_REQUIRED,
    TASK_COMPLETED, TASK_CANCELED, TASK_FAILED, TASK_REJECTED,
}

TERMINAL_STATES = {TASK_COMPLETED, TASK_FAILED, TASK_CANCELED, TASK_REJECTED}


def build_agent_card(
    agent_name: str,
    agent_pub_key: str,
    messaging_address: str,
    skills: list[dict],
    description: str = "",
    version: str = "1.0.0",
) -> dict:
    """
    Build an A2A v1.0.0 compatible Agent Card.
    Spec: https://github.com/a2aproject/A2A

    Published at /.well-known/agent-card.json on HTTP agents.
    For Logos agents, published to Logos Messaging discovery topics.
    """
    return {
        "agentCard": {
            "name": agent_name,
            "description": description or "Autonomous AI agent on Logos/Agora",
            "version": version,
            "supportedInterfaces": [
                {
                    "url": f"logos://{messaging_address}",
                    "protocolBinding": "JSONRPC",
                    "protocolVersion": A2A_PROTOCOL_VERSION,
                },
            ],
            "capabilities": {
                "streaming": True,
                "pushNotifications": True,
                "extendedAgentCard": False,
            },
            "defaultInputModes": ["application/json", "text/plain"],
            "defaultOutputModes": ["application/json", "text/plain"],
            "skills": [
                {
                    "id": s["name"],
                    "name": s["name"],
                    "description": s.get("description", ""),
                    "tags": [s.get("category", "misc")],
                    "inputModes": ["application/json"],
                    "outputModes": ["application/json"],
                }
                for s in skills
            ],
            "securitySchemes": {
                "logos": {
                    "type": "logos-identity",
                    "description": "Logos ZkPublicKey identity verification",
                },
            },
            "securityRequirements": [{"logos": ["identity"]}],
            "provider": {
                "organization": "daemon-ai",
                "url": f"logos://{messaging_address}",
            },
            # Logos-specific extensions
            "identity": {
                "publicKey": agent_pub_key,
                "messagingAddress": messaging_address,
            },
        }
    }


class TaskStore:
    """In-memory store for A2A task state (persisted to disk for recovery)."""

    def __init__(self):
        self._tasks: dict[str, dict] = {}

    def create(self, task_id: str, skill: str, params: dict,
               caller: str, agent_address: str) -> dict:
        task = {
            "id": task_id,
            "state": TASK_SUBMITTED,
            "skill": skill,
            "params": params,
            "caller": caller,
            "agent_address": agent_address,
            "created_at": time.time(),
            "updated_at": time.time(),
            "result": None,
            "error": None,
            "history": [{"state": TASK_SUBMITTED, "ts": time.time()}],
        }
        self._tasks[task_id] = task
        return task

    def update_state(self, task_id: str, state: str,
                     result: Optional[dict] = None, error: Optional[str] = None) -> Optional[dict]:
        task = self._tasks.get(task_id)
        if not task:
            return None
        task["state"] = state
        task["updated_at"] = time.time()
        task["history"].append({"state": state, "ts": time.time()})
        if result is not None:
            task["result"] = result
        if error is not None:
            task["error"] = error
        return task

    def get(self, task_id: str) -> Optional[dict]:
        return self._tasks.get(task_id)

    def list_active(self) -> list[dict]:
        return [
            t for t in self._tasks.values()
            if t["state"] in (TASK_SUBMITTED, TASK_WORKING, TASK_INPUT_REQUIRED)
        ]

    def list_all(self, limit: int = 50) -> list[dict]:
        return sorted(self._tasks.values(), key=lambda t: t["updated_at"], reverse=True)[:limit]


# Global task store — shared across skills
task_store = TaskStore()


# ── A2A Skills ──────────────────────────────────────────────────────

class AgentCardSkill(Skill):
    name = "agent.card"
    description = "Return A2A-compatible Agent Card with signed JSON declaration"
    category = "agent"
    parameters = {}

    def __init__(self, agent_name: str, agent_pub_key: str,
                 messaging_address: str, skill_registry: SkillRegistry):
        self._agent_name = agent_name
        self._pub_key = agent_pub_key
        self._msg_address = messaging_address
        self._registry = skill_registry

    async def execute(self, params: dict, context: SkillContext) -> SkillResult:
        card = build_agent_card(
            agent_name=self._agent_name,
            agent_pub_key=self._pub_key,
            messaging_address=self._msg_address,
            skills=self._registry.list_skills(),
        )
        return SkillResult.ok(card)


class AgentDiscoverSkill(Skill):
    name = "agent.discover"
    description = "Fetch Agent Cards from Logos Messaging discovery topics"
    category = "agent"
    parameters = {
        "topic": {"type": "string", "required": True, "description": "Discovery topic to scan"},
    }

    def __init__(self, messaging: LogosMessagingClient):
        self._messaging = messaging

    async def execute(self, params: dict, context: SkillContext) -> SkillResult:
        # Subscribe to discovery topic and collect Agent Cards
        cards = await self._messaging.discover_agents(params["topic"])
        return SkillResult.ok({
            "agents": cards,
            "count": len(cards),
            "topic": params["topic"],
        })


class AgentTaskSkill(Skill):
    name = "agent.task"
    description = "Send task request to another agent following A2A lifecycle"
    category = "agent"
    parameters = {
        "agent_address": {"type": "string", "required": True, "description": "Target agent's Logos address"},
        "skill": {"type": "string", "required": True, "description": "Skill to invoke on target agent"},
        "params": {"type": "string", "required": False, "description": "Task parameters (JSON)"},
    }

    def __init__(self, messaging: LogosMessagingClient):
        self._messaging = messaging

    async def execute(self, params: dict, context: SkillContext) -> SkillResult:
        task_params = {}
        if params.get("params"):
            task_params = json.loads(params["params"])

        task_id = secrets.token_hex(16)

        # Create local task record
        task = task_store.create(
            task_id=task_id,
            skill=params["skill"],
            params=task_params,
            caller=context.agent_pub_key,
            agent_address=params["agent_address"],
        )

        # Send task request via Logos Messaging (A2A v1.0.0 format)
        a2a_message = {
            "jsonrpc": "2.0",
            "method": "message/send",
            "params": {
                "message": {
                    "role": "user",
                    "parts": [{"type": "text", "text": json.dumps({
                        "skill": params["skill"],
                        "params": task_params,
                    })}],
                    "taskId": task_id,
                    "metadata": {
                        "sender": context.agent_pub_key,
                        "transport": A2A_TRANSPORT,
                    },
                },
            },
        }

        await self._messaging.send(
            params["agent_address"],
            json.dumps(a2a_message),
        )

        return SkillResult.ok({
            "task_id": task_id,
            "state": TASK_SUBMITTED,
            "agent_address": params["agent_address"],
            "skill": params["skill"],
        })


class AgentSubscribeSkill(Skill):
    name = "agent.subscribe"
    description = "Subscribe to streaming status updates for an A2A task"
    category = "agent"
    parameters = {
        "agent_address": {"type": "string", "required": True, "description": "Target agent's address"},
        "task_id": {"type": "string", "required": True, "description": "Task ID to subscribe to"},
    }

    def __init__(self, messaging: LogosMessagingClient):
        self._messaging = messaging

    async def execute(self, params: dict, context: SkillContext) -> SkillResult:
        task = task_store.get(params["task_id"])
        if not task:
            return SkillResult.fail(f"Unknown task: {params['task_id']}")

        # Send subscribe request via A2A v1.0.0
        a2a_message = {
            "jsonrpc": "2.0",
            "method": "tasks/subscribe",
            "params": {
                "taskId": params["task_id"],
            },
        }

        await self._messaging.send(
            params["agent_address"],
            json.dumps(a2a_message),
        )

        return SkillResult.ok({
            "subscribed": True,
            "task_id": params["task_id"],
            "current_state": task["state"],
        })


class AgentCancelSkill(Skill):
    name = "agent.cancel"
    description = "Cancel an in-progress A2A task with refund"
    category = "agent"
    parameters = {
        "agent_address": {"type": "string", "required": True, "description": "Target agent's address"},
        "task_id": {"type": "string", "required": True, "description": "Task ID to cancel"},
    }

    def __init__(self, messaging: LogosMessagingClient):
        self._messaging = messaging

    async def execute(self, params: dict, context: SkillContext) -> SkillResult:
        task = task_store.get(params["task_id"])
        if not task:
            return SkillResult.fail(f"Unknown task: {params['task_id']}")

        if task["state"] in TERMINAL_STATES:
            return SkillResult.fail(f"Task already in terminal state: {task['state']}")

        # Send cancel request via A2A v1.0.0
        a2a_message = {
            "jsonrpc": "2.0",
            "method": "tasks/cancel",
            "params": {"taskId": params["task_id"]},
        }

        await self._messaging.send(
            params["agent_address"],
            json.dumps(a2a_message),
        )

        task_store.update_state(params["task_id"], TASK_CANCELED)

        return SkillResult.ok({
            "canceled": True,
            "task_id": params["task_id"],
            "refund_requested": True,
        })


def register_agent_skills(registry: SkillRegistry, agent_name: str,
                          agent_pub_key: str, messaging_address: str,
                          messaging: LogosMessagingClient):
    """Register all A2A agent coordination skills."""
    registry.register(AgentCardSkill(agent_name, agent_pub_key, messaging_address, registry))
    registry.register(AgentDiscoverSkill(messaging))
    registry.register(AgentTaskSkill(messaging))
    registry.register(AgentSubscribeSkill(messaging))
    registry.register(AgentCancelSkill(messaging))
