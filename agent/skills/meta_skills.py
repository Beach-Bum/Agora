"""
agent/skills/meta_skills.py

LP-0008 required meta skills.

Skills:
  meta.skills    — list available skills and parameters
  meta.status    — report agent state, balance, storage usage, active tasks
  meta.configure — update runtime configuration
"""

from agent.skills.base import Skill, SkillContext, SkillResult, SkillRegistry
from agent.core.daemon_wallet import DaemonWallet
from agent.skills.agent_skills import task_store


class MetaSkillsSkill(Skill):
    name = "meta.skills"
    description = "List all available skills and their parameters"
    category = "meta"
    parameters = {
        "category": {"type": "string", "required": False, "description": "Filter by category"},
    }

    def __init__(self, registry: SkillRegistry):
        self._registry = registry

    async def execute(self, params: dict, context: SkillContext) -> SkillResult:
        category = params.get("category")
        if category:
            skills = self._registry.list_by_category(category)
        else:
            skills = self._registry.list_skills()
        return SkillResult.ok({
            "skills": skills,
            "count": len(skills),
        })


class MetaStatusSkill(Skill):
    name = "meta.status"
    description = "Report agent state, balance, storage usage, and active tasks"
    category = "meta"
    parameters = {}

    def __init__(self, wallet: DaemonWallet, registry: SkillRegistry):
        self._wallet = wallet
        self._registry = registry

    async def execute(self, params: dict, context: SkillContext) -> SkillResult:
        wallet_state = self._wallet.state()
        active_tasks = task_store.list_active()

        return SkillResult.ok({
            "agent": {
                "pub_key": wallet_state["pub_key"],
                "frozen": wallet_state["frozen"],
            },
            "wallet": {
                "balance_nom": wallet_state["balance_nom"],
                "available_nom": wallet_state["available_nom"],
                "earned_total_nom": wallet_state["earned_total_nom"],
            },
            "skills": {
                "total": self._registry.count,
                "categories": list(set(
                    s.get("category", "misc")
                    for s in self._registry.list_skills()
                )),
            },
            "tasks": {
                "active": len(active_tasks),
                "active_ids": [t["id"] for t in active_tasks],
            },
        })


class MetaConfigureSkill(Skill):
    name = "meta.configure"
    description = "Update runtime configuration"
    category = "meta"
    parameters = {
        "key": {"type": "string", "required": True, "description": "Configuration key"},
        "value": {"type": "string", "required": True, "description": "Configuration value"},
    }

    ALLOWED_KEYS = {
        "spending.max_per_tx": "max_per_tx_nom",
        "spending.daily_cap": "daily_cap_nom",
        "spending.frozen": "frozen",
        "agent.auto_sell": "auto_sell",
        "agent.auto_buy": "auto_buy",
    }

    def __init__(self, wallet: DaemonWallet):
        self._wallet = wallet

    async def execute(self, params: dict, context: SkillContext) -> SkillResult:
        key = params["key"]
        value = params["value"]

        if key not in self.ALLOWED_KEYS:
            return SkillResult.fail(
                f"Unknown config key: {key}. "
                f"Allowed: {list(self.ALLOWED_KEYS.keys())}"
            )

        if key == "spending.max_per_tx":
            self._wallet.update_policy(max_per_tx_nom=float(value))
        elif key == "spending.daily_cap":
            self._wallet.update_policy(daily_cap_nom=float(value))
        elif key == "spending.frozen":
            if value.lower() in ("true", "1", "yes"):
                self._wallet.freeze()
            else:
                self._wallet.unfreeze()
        elif key.startswith("agent."):
            # Agent config stored separately
            pass

        return SkillResult.ok({
            "updated": True,
            "key": key,
            "value": value,
        })


def register_meta_skills(registry: SkillRegistry, wallet: DaemonWallet):
    """Register all meta skills."""
    registry.register(MetaSkillsSkill(registry))
    registry.register(MetaStatusSkill(wallet, registry))
    registry.register(MetaConfigureSkill(wallet))
