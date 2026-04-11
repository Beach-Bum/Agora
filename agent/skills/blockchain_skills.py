"""
agent/skills/blockchain_skills.py

LP-0008 required blockchain skills using Logos Blockchain (LEZ).

Skills:
  wallet.balance  — return agent's current shielded token balance
  wallet.send     — send tokens; enforces spending threshold
  wallet.history  — return recent transaction summary
  program.query   — read LEZ program state
  program.call    — submit program transaction
  program.deploy  — deploy compiled LEZ program binary
"""

from agent.skills.base import Skill, SkillContext, SkillResult
from agent.core.daemon_wallet import DaemonWallet
from agent.logos.blockchain import LogosBlockchainClient


class WalletBalanceSkill(Skill):
    name = "wallet.balance"
    description = "Return agent's current shielded token balance"
    category = "blockchain"
    parameters = {}

    def __init__(self, wallet: DaemonWallet):
        self._wallet = wallet

    async def execute(self, params: dict, context: SkillContext) -> SkillResult:
        state = self._wallet.state()
        return SkillResult.ok({
            "balance_nom": state["balance_nom"],
            "available_nom": state["available_nom"],
            "locked_in_escrow_nom": state["locked_in_escrow_nom"],
            "earned_total_nom": state["earned_total_nom"],
            "frozen": state["frozen"],
        })


class WalletSendSkill(Skill):
    name = "wallet.send"
    description = "Send tokens to a recipient; enforces spending threshold"
    category = "blockchain"
    requires_approval = True  # Above-threshold sends need owner approval
    parameters = {
        "recipient": {"type": "string", "required": True, "description": "Recipient address (pub key)"},
        "amount": {"type": "number", "required": True, "description": "Amount in NOM"},
    }

    def __init__(self, wallet: DaemonWallet, blockchain: LogosBlockchainClient):
        self._wallet = wallet
        self._blockchain = blockchain

    async def execute(self, params: dict, context: SkillContext) -> SkillResult:
        amount = float(params["amount"])
        recipient = params["recipient"]

        # Check spending policy — check_spend returns (allowed: bool, reason: str)
        allowed, reason = self._wallet.check_spend(amount, "transfer")
        if not allowed:
            if amount > self._wallet.policy.max_per_tx_nom:
                return SkillResult.fail(
                    f"Above threshold: {amount} NOM requires owner approval. "
                    f"Reason: {reason}"
                )
            return SkillResult.fail(f"Spending denied: {reason}")

        # Execute the transfer
        import secrets
        tx_ref = secrets.token_hex(16)
        spend_result = self._wallet.spend(amount, recipient[:20], tx_ref, "transfer")

        # Submit on-chain
        tx = await self._blockchain.send_tokens(recipient, str(amount))

        return SkillResult.ok({
            "sent": True,
            "amount": amount,
            "recipient": recipient,
            "tx_hash": tx.get("tx_hash", tx_ref),
            "remaining_balance": self._wallet._balance_nom,
        })


class WalletHistorySkill(Skill):
    name = "wallet.history"
    description = "Return recent transaction summary"
    category = "blockchain"
    parameters = {
        "limit": {"type": "number", "required": False, "description": "Max entries (default 20)"},
    }

    def __init__(self, wallet: DaemonWallet):
        self._wallet = wallet

    async def execute(self, params: dict, context: SkillContext) -> SkillResult:
        limit = int(params.get("limit", 20))
        entries = self._wallet.audit_log(limit)
        return SkillResult.ok({
            "entries": entries,
            "count": len(entries),
        })


class ProgramQuerySkill(Skill):
    name = "program.query"
    description = "Read LEZ program state"
    category = "blockchain"
    parameters = {
        "program_id": {"type": "string", "required": True, "description": "Program address"},
        "params": {"type": "string", "required": False, "description": "Query parameters (JSON)"},
    }

    def __init__(self, blockchain: LogosBlockchainClient):
        self._blockchain = blockchain

    async def execute(self, params: dict, context: SkillContext) -> SkillResult:
        import json
        query_params = {}
        if params.get("params"):
            query_params = json.loads(params["params"])
        result = await self._blockchain.query_program(params["program_id"], query_params)
        return SkillResult.ok(result)


class ProgramCallSkill(Skill):
    name = "program.call"
    description = "Submit a LEZ program transaction"
    category = "blockchain"
    requires_approval = True
    parameters = {
        "program_id": {"type": "string", "required": True, "description": "Program address"},
        "instruction": {"type": "string", "required": True, "description": "Instruction name"},
        "params": {"type": "string", "required": False, "description": "Instruction parameters (JSON)"},
    }

    def __init__(self, wallet: DaemonWallet, blockchain: LogosBlockchainClient):
        self._wallet = wallet
        self._blockchain = blockchain

    async def execute(self, params: dict, context: SkillContext) -> SkillResult:
        import json
        call_params = {}
        if params.get("params"):
            call_params = json.loads(params["params"])
        result = await self._blockchain.call_program(
            params["program_id"], params["instruction"], call_params
        )
        return SkillResult.ok({
            "tx_hash": result.get("tx_hash", ""),
            "program_id": params["program_id"],
            "instruction": params["instruction"],
        })


class ProgramDeploySkill(Skill):
    name = "program.deploy"
    description = "Deploy a compiled LEZ program binary"
    category = "blockchain"
    requires_approval = True
    parameters = {
        "binary_path": {"type": "string", "required": True, "description": "Path to compiled program binary"},
    }

    def __init__(self, wallet: DaemonWallet, blockchain: LogosBlockchainClient):
        self._wallet = wallet
        self._blockchain = blockchain

    async def execute(self, params: dict, context: SkillContext) -> SkillResult:
        result = await self._blockchain.deploy_program(params["binary_path"])
        return SkillResult.ok({
            "deployed": True,
            "program_id": result.get("program_id", ""),
            "tx_hash": result.get("tx_hash", ""),
        })


def register_blockchain_skills(registry, wallet: DaemonWallet, blockchain: LogosBlockchainClient):
    """Register all blockchain skills with the given registry."""
    registry.register(WalletBalanceSkill(wallet))
    registry.register(WalletSendSkill(wallet, blockchain))
    registry.register(WalletHistorySkill(wallet))
    registry.register(ProgramQuerySkill(blockchain))
    registry.register(ProgramCallSkill(wallet, blockchain))
    registry.register(ProgramDeploySkill(wallet, blockchain))
