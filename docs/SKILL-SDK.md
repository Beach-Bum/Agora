# Skill SDK Reference

## Overview

The Skill SDK is a pluggable architecture for agent capabilities. Each skill is an isolated, self-describing unit that can be registered, discovered, invoked, and composed.

## Creating a Skill

```python
from agent.skills.base import Skill, SkillContext, SkillResult

class MySkill(Skill):
    name = "custom.greet"
    description = "Greet a user by name"
    category = "custom"
    parameters = {
        "name": {"type": "string", "required": True, "description": "Name to greet"},
    }
    requires_approval = False

    async def execute(self, params: dict, context: SkillContext) -> SkillResult:
        return SkillResult.ok({"message": f"Hello, {params['name']}!"})
```

## Registering Skills

```python
from agent.skills.base import SkillRegistry

registry = SkillRegistry()
registry.register(MySkill())
```

Or use a registration function for a group of skills:

```python
def register_my_skills(registry: SkillRegistry, my_service):
    registry.register(SkillA(my_service))
    registry.register(SkillB(my_service))
```

## Invoking Skills

```python
from agent.skills.base import SkillContext

context = SkillContext(
    agent_pub_key="03abc...",
    wallet_balance=100.0,
    caller="owner",
)
result = await registry.invoke("custom.greet", {"name": "Alice"}, context)
# result.success == True
# result.data == {"message": "Hello, Alice!"}
```

## Skill Lifecycle

1. **Registration**: Skills register with the `SkillRegistry` at startup
2. **Discovery**: `meta.skills` or `GET /skills` lists all registered skills
3. **Validation**: Parameters checked against schema before execution
4. **Execution**: Wrapped in try/except + timeout — failures never crash the agent
5. **Result**: Returns `SkillResult` with success/data or error

## SkillContext

Every skill receives a `SkillContext` with:

| Field | Type | Description |
|-------|------|-------------|
| `agent_pub_key` | str | Agent's public key |
| `wallet_balance` | float | Current NOM balance |
| `caller` | str | Who invoked: "owner", "self", or "peer:<address>" |
| `task_id` | str | A2A task ID (if invoked by peer) |
| `timeout_ms` | int | Max execution time (default 30000) |

## SkillResult

| Field | Type | Description |
|-------|------|-------------|
| `success` | bool | Whether execution succeeded |
| `data` | Any | Result payload (on success) |
| `error` | str | Error message (on failure) |
| `duration_ms` | float | Execution time |

## Categories

| Category | Description |
|----------|-------------|
| `storage` | File upload/download via Logos Storage |
| `messaging` | Communication via Logos Messaging |
| `blockchain` | Wallet, programs via Logos Blockchain |
| `agent` | A2A protocol operations |
| `meta` | Self-introspection and configuration |
| `custom` | Third-party skills |

## Bridge API

```
GET  /skills                    — list all skills
GET  /skills?category=storage   — filter by category
POST /skills/invoke             — invoke a skill
     body: {"skill": "wallet.balance", "params": {}}
```

## CLI

```bash
agora skills                           # list all
agora skills --category blockchain     # filter
agora invoke wallet.balance            # invoke
agora invoke wallet.send --params '{"recipient":"03abc...","amount":5}'
```

## Third-Party Skills

Third-party skills register without modifying core:

```python
# my_plugin/skills.py
from agent.skills.base import Skill, SkillResult, SkillContext

class WeatherSkill(Skill):
    name = "weather.forecast"
    description = "Get weather forecast for a location"
    category = "custom"
    parameters = {
        "location": {"type": "string", "required": True},
    }

    async def execute(self, params, context):
        # ... fetch weather ...
        return SkillResult.ok({"temp": 22, "condition": "sunny"})

def register(registry):
    registry.register(WeatherSkill())
```

Load at startup:

```python
from my_plugin.skills import register
register(daemon.registry)
```
