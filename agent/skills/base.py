"""
agent/skills/base.py

Skill SDK — base classes and registry for pluggable agent skills.

Usage:
    from agent.skills.base import Skill, SkillRegistry, SkillResult

    class MySkill(Skill):
        name = "custom.greet"
        description = "Greet a user by name"
        parameters = {"name": {"type": "string", "required": True}}

        async def execute(self, params: dict, context: SkillContext) -> SkillResult:
            return SkillResult.ok({"message": f"Hello, {params['name']}!"})

    registry = SkillRegistry()
    registry.register(MySkill())
"""

import asyncio
import time
import traceback
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Any, Optional


@dataclass
class SkillContext:
    """Runtime context passed to every skill execution."""
    agent_pub_key: str = ""
    wallet_balance: float = 0.0
    caller: str = "owner"           # "owner" | "self" | "peer:<address>"
    task_id: Optional[str] = None   # A2A task ID if invoked by peer
    timeout_ms: int = 30000


@dataclass
class SkillResult:
    """Standardized result from skill execution."""
    success: bool
    data: Any = None
    error: Optional[str] = None
    duration_ms: float = 0.0

    @classmethod
    def ok(cls, data: Any = None, duration_ms: float = 0.0) -> "SkillResult":
        return cls(success=True, data=data, duration_ms=duration_ms)

    @classmethod
    def fail(cls, error: str, duration_ms: float = 0.0) -> "SkillResult":
        return cls(success=False, error=error, duration_ms=duration_ms)

    def to_dict(self) -> dict:
        d = {"success": self.success, "duration_ms": round(self.duration_ms, 1)}
        if self.success:
            d["data"] = self.data
        else:
            d["error"] = self.error
        return d


class Skill(ABC):
    """
    Base class for all agent skills.

    Subclass this and implement execute() to create a new skill.
    Skills are isolated — exceptions in execute() are caught and
    returned as SkillResult.fail() without crashing the module.
    """

    # Override in subclass
    name: str = ""
    description: str = ""
    parameters: dict = {}   # JSON Schema-like parameter definitions
    category: str = "misc"  # "storage" | "messaging" | "blockchain" | "agent" | "meta"
    requires_approval: bool = False  # If True, above-threshold invocations need owner OK

    @abstractmethod
    async def execute(self, params: dict, context: SkillContext) -> SkillResult:
        """Execute the skill with given parameters. Must be implemented by subclass."""
        ...

    def validate_params(self, params: dict) -> Optional[str]:
        """Validate parameters against the schema. Returns error string or None."""
        for param_name, schema in self.parameters.items():
            if schema.get("required", False) and param_name not in params:
                return f"Missing required parameter: {param_name}"
            if param_name in params:
                expected_type = schema.get("type", "string")
                value = params[param_name]
                if expected_type == "string" and not isinstance(value, str):
                    return f"Parameter '{param_name}' must be a string"
                elif expected_type == "number" and not isinstance(value, (int, float)):
                    return f"Parameter '{param_name}' must be a number"
                elif expected_type == "boolean" and not isinstance(value, bool):
                    return f"Parameter '{param_name}' must be a boolean"
        return None

    def to_dict(self) -> dict:
        """Serialize skill metadata for meta.skills() and A2A Agent Cards."""
        return {
            "name": self.name,
            "description": self.description,
            "parameters": self.parameters,
            "category": self.category,
            "requires_approval": self.requires_approval,
        }


class SkillRegistry:
    """
    Registry of available skills. Supports dynamic registration
    for third-party skill plugins.
    """

    def __init__(self):
        self._skills: dict[str, Skill] = {}

    def register(self, skill: Skill) -> None:
        """Register a skill. Raises ValueError if name already taken."""
        if skill.name in self._skills:
            raise ValueError(f"Skill '{skill.name}' already registered")
        if not skill.name:
            raise ValueError("Skill must have a non-empty name")
        self._skills[skill.name] = skill

    def unregister(self, name: str) -> None:
        """Remove a skill from the registry."""
        self._skills.pop(name, None)

    def get(self, name: str) -> Optional[Skill]:
        """Look up a skill by name."""
        return self._skills.get(name)

    def list_skills(self) -> list[dict]:
        """List all registered skills (for meta.skills())."""
        return [s.to_dict() for s in self._skills.values()]

    def list_by_category(self, category: str) -> list[dict]:
        """List skills in a specific category."""
        return [s.to_dict() for s in self._skills.values() if s.category == category]

    async def invoke(self, name: str, params: dict, context: SkillContext) -> SkillResult:
        """
        Invoke a skill by name with isolation.
        Catches all exceptions — a failing skill never crashes the module.
        """
        skill = self._skills.get(name)
        if not skill:
            return SkillResult.fail(f"Unknown skill: {name}")

        # Validate parameters
        error = skill.validate_params(params)
        if error:
            return SkillResult.fail(error)

        # Execute with isolation and timeout
        t0 = time.time()
        try:
            result = await asyncio.wait_for(
                skill.execute(params, context),
                timeout=context.timeout_ms / 1000.0,
            )
            result.duration_ms = (time.time() - t0) * 1000
            return result
        except asyncio.TimeoutError:
            duration = (time.time() - t0) * 1000
            return SkillResult.fail(f"Skill '{name}' timed out after {context.timeout_ms}ms", duration)
        except Exception as e:
            duration = (time.time() - t0) * 1000
            # Log the traceback but don't expose internals
            traceback.print_exc()
            return SkillResult.fail(f"Skill '{name}' failed: {type(e).__name__}: {e}", duration)

    @property
    def count(self) -> int:
        return len(self._skills)
