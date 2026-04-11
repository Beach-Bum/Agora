"""
agent/logos/blockchain.py

Logos Blockchain LEZ (Logos Execution Zone) integration for Agora.
Handles agent identity registration, shielded payments, and escrow contracts.

Wraps the LEZ HTTP API exposed by a running nomos-node.

LEZ API (nomos-node):
  POST /mempool/add/tx                      — submit a SignedMantleTx
  GET  /wallet/:public_key/balance          — query shielded balance (notes)
  POST /wallet/transactions/transfer-funds  — shielded token transfer
  GET  /cryptarchia/info                    — consensus state
  GET  /cryptarchia/headers                 — block headers (range query)
  GET  /cryptarchia/lib-stream              — NDJSON stream of finalized blocks
  POST /sdp/declaration                     — SDP service declaration
  POST /channel/deposit                     — deposit into zone channel
  GET  /channel/:id                         — query channel state

Devnet: https://devnet.blockchain.logos.co/node/{0-3}/
"""

import httpx
import json
import time
from dataclasses import dataclass
from typing import Optional

# LEZ devnet node URLs
LEZ_DEVNET_NODES = [
    "https://devnet.blockchain.logos.co/node/0",
    "https://devnet.blockchain.logos.co/node/1",
    "https://devnet.blockchain.logos.co/node/2",
    "https://devnet.blockchain.logos.co/node/3",
]


@dataclass
class AgentIdentity:
    agent_id: str           # ZkPublicKey hex (32 bytes)
    tx_hash: str            # identity registration transaction
    stake: str              # NOM staked (string, base units)
    block: int
    mock: bool = False


@dataclass
class EscrowRecord:
    escrow_id: str
    buyer_id: str
    seller_id: str
    amount: str             # NOM
    delivery_hash: str      # committed hash of expected output
    timeout_ms: int
    slash_bps: int
    status: str             # pending | delivered | released | slashed | expired
    tx_hash: str
    block: int
    mock: bool = False


@dataclass
class PaymentResult:
    tx_hash: str
    from_id: str
    to_id: str
    amount: str
    block: int
    mock: bool = False


class LogosBlockchainClient:
    """
    Client for the LEZ (Logos Execution Zone) HTTP API via nomos-node.

    Covers:
    - Agent identity registration (SDP declaration)
    - Shielded NOM transfers (ZK note-based UTXO)
    - Escrow create / release / dispute (LEZ program)
    - Reputation reads (LEZ program)
    - Chain state (Cryptarchia consensus info, balance)

    Degrades to mock mode when no node is reachable.
    """

    def __init__(self, node_url: str = "http://localhost:3001"):
        self.node_url = node_url
        self._mock = False

    async def check_node(self) -> bool:
        """Check node health via Cryptarchia info endpoint."""
        try:
            async with httpx.AsyncClient() as client:
                # LEZ uses /cryptarchia/info as the health check
                resp = await client.get(f"{self.node_url}/cryptarchia/info", timeout=5.0)
                self._mock = resp.status_code != 200
        except Exception:
            self._mock = True
        status = "connected" if not self._mock else "mock mode"
        print(f"[LEZ] Node at {self.node_url}: {status}")
        return not self._mock

    # ── Identity ──────────────────────────────────────────────────

    async def register_identity(
        self,
        agent_pub_key_hex: str,
        stake_nom: str,
        capability_hash: str,
    ) -> AgentIdentity:
        """
        Register an agent identity on-chain via the LSSA identity contract.
        Stakes NOM tokens as credibility bond.
        """
        if self._mock:
            return AgentIdentity(
                agent_id=agent_pub_key_hex,
                tx_hash="0x" + "a" * 64,
                stake=stake_nom,
                block=848000 + int(time.time()) % 1000,
                mock=True,
            )

        try:
            async with httpx.AsyncClient() as client:
                resp = await client.post(
                    f"{self.node_url}/lssa/identity/register",
                    json={
                        "agentPubKey": agent_pub_key_hex,
                        "stakeNom": stake_nom,
                        "capabilityHash": capability_hash,
                    },
                    timeout=30.0,
                )
                data = resp.json()
                return AgentIdentity(
                    agent_id=agent_pub_key_hex,
                    tx_hash=data["txHash"],
                    stake=stake_nom,
                    block=data["block"],
                )
        except Exception as e:
            print(f"[Logos Blockchain] register_identity failed: {e}")
            return AgentIdentity(
                agent_id=agent_pub_key_hex,
                tx_hash="0x" + "b" * 64,
                stake=stake_nom,
                block=0,
                mock=True,
            )

    # ── Payments ──────────────────────────────────────────────────

    async def transfer(
        self,
        from_priv_key_hex: str,
        to_agent_id: str,
        amount_nom: str,
        private: bool = True,
    ) -> PaymentResult:
        """
        Send NOM tokens to another agent.
        If private=True, routes through the Blend Network (metadata private).
        """
        if self._mock:
            return PaymentResult(
                tx_hash="0x" + "c" * 64,
                from_id="sender",
                to_id=to_agent_id,
                amount=amount_nom,
                block=848000,
                mock=True,
            )

        try:
            async with httpx.AsyncClient() as client:
                resp = await client.post(
                    f"{self.node_url}/lssa/transfer",
                    json={
                        "fromPrivKey": from_priv_key_hex,
                        "toAgentId": to_agent_id,
                        "amountNom": amount_nom,
                        "private": private,
                    },
                    timeout=30.0,
                )
                data = resp.json()
                return PaymentResult(
                    tx_hash=data["txHash"],
                    from_id=data["from"],
                    to_id=to_agent_id,
                    amount=amount_nom,
                    block=data["block"],
                )
        except Exception as e:
            print(f"[Logos Blockchain] transfer failed: {e}")
            raise

    # ── Escrow ────────────────────────────────────────────────────

    async def create_escrow(
        self,
        buyer_priv_key_hex: str,
        seller_id: str,
        amount_nom: str,
        delivery_hash: str,
        buyer_nonce: str,        # FIX-2: included in escrow commitment
        timeout_ms: int,
        slash_bps: int = 500,
    ) -> EscrowRecord:
        """
        Lock NOM in the LSSA escrow contract.
        Funds are held until delivery is confirmed or timeout expires.
        """
        if self._mock:
            return EscrowRecord(
                escrow_id="0xescrow" + "d" * 57,
                buyer_id="buyer",
                seller_id=seller_id,
                amount=amount_nom,
                delivery_hash=delivery_hash,
                timeout_ms=timeout_ms,
                slash_bps=slash_bps,
                status="pending",
                tx_hash="0x" + "d" * 64,
                block=848001,
                mock=True,
            )

        try:
            async with httpx.AsyncClient() as client:
                resp = await client.post(
                    f"{self.node_url}/lssa/escrow/create",
                    json={
                        "buyerPrivKey": buyer_priv_key_hex,
                        "sellerId": seller_id,
                        "amountNom": amount_nom,
                        "deliveryHash": delivery_hash,
                        "buyerNonce": buyer_nonce,    # FIX-2
                        "timeoutMs": timeout_ms,
                        "slashBps": slash_bps,
                    },
                    timeout=30.0,
                )
                data = resp.json()
                return EscrowRecord(
                    escrow_id=data["escrowId"],
                    buyer_id=data["buyerId"],
                    seller_id=seller_id,
                    amount=amount_nom,
                    delivery_hash=delivery_hash,
                    timeout_ms=timeout_ms,
                    slash_bps=slash_bps,
                    status="pending",
                    tx_hash=data["txHash"],
                    block=data["block"],
                )
        except Exception as e:
            print(f"[Logos Blockchain] create_escrow failed: {e}")
            raise

    async def release_escrow(
        self,
        buyer_priv_key_hex: str,
        escrow_id: str,
        actual_output_hash: str,
        buyer_nonce: str = "",    # FIX-2: required by LSSA escrow contract
    ) -> bool:
        """
        Buyer confirms delivery and releases escrow to seller.
        Verifies actual_output_hash matches the committed delivery_hash.
        """
        if self._mock:
            print(f"[Logos Blockchain] Mock: escrow {escrow_id[:20]}... released")
            return True

        try:
            async with httpx.AsyncClient() as client:
                resp = await client.post(
                    f"{self.node_url}/lssa/escrow/release",
                    json={
                        "buyerPrivKey": buyer_priv_key_hex,
                        "escrowId": escrow_id,
                        "actualOutputHash": actual_output_hash,
                        "buyerNonce": buyer_nonce,    # FIX-2
                    },
                    timeout=30.0,
                )
                return resp.status_code == 200
        except Exception as e:
            print(f"[Logos Blockchain] release_escrow failed: {e}")
            return False

    async def dispute_escrow(
        self,
        initiator_priv_key_hex: str,
        escrow_id: str,
        evidence: str,
    ) -> bool:
        """Initiate a dispute on an escrow — triggers the slash mechanism."""
        if self._mock:
            print(f"[Logos Blockchain] Mock: dispute on {escrow_id[:20]}...")
            return True

        try:
            async with httpx.AsyncClient() as client:
                resp = await client.post(
                    f"{self.node_url}/lssa/escrow/dispute",
                    json={
                        "initiatorPrivKey": initiator_priv_key_hex,
                        "escrowId": escrow_id,
                        "evidence": evidence,
                    },
                    timeout=30.0,
                )
                return resp.status_code == 200
        except Exception as e:
            print(f"[Logos Blockchain] dispute_escrow failed: {e}")
            return False

    # ── Reputation ────────────────────────────────────────────────

    async def get_reputation(self, agent_id: str) -> float:
        """Read agent reputation score from the LSSA reputation registry (0.0–1.0)."""
        if self._mock:
            return 0.85

        try:
            async with httpx.AsyncClient() as client:
                resp = await client.get(
                    f"{self.node_url}/lssa/reputation/{agent_id}",
                    timeout=10.0,
                )
                data = resp.json()
                return float(data.get("score", 0.0))
        except Exception:
            return 0.0

    # ── Utilities ──────────────────────────────────────────────────

    async def get_balance(self, agent_id: str) -> str:
        """Get NOM balance for an agent identity (ZkPublicKey)."""
        if self._mock:
            return "10000"

        try:
            async with httpx.AsyncClient() as client:
                # LEZ endpoint: /wallet/:public_key/balance
                resp = await client.get(
                    f"{self.node_url}/wallet/{agent_id}/balance",
                    timeout=10.0,
                )
                data = resp.json()
                # LEZ returns notes-based balance; sum the values
                if isinstance(data, list):
                    total = sum(n.get("value", 0) for n in data)
                    return str(total)
                return str(data.get("value", data.get("balance", "0")))
        except Exception:
            return "0"

    async def get_chain_state(self) -> dict:
        """Get current consensus state from Cryptarchia."""
        if self._mock:
            return {"blockHeight": 848000 + int(time.time()) % 10000, "mock": True}

        try:
            async with httpx.AsyncClient() as client:
                # LEZ endpoint: /cryptarchia/info
                resp = await client.get(
                    f"{self.node_url}/cryptarchia/info",
                    timeout=10.0,
                )
                return resp.json()
        except Exception:
            return {"blockHeight": 0, "mock": True}

    # ── Skill-facing methods (LP-0008) ───────────────────────────

    async def send_tokens(self, recipient: str, amount: str,
                          funding_key: str = "", change_key: str = "") -> dict:
        """
        Send tokens to a recipient (shielded transfer on LEZ).

        LEZ endpoint: POST /wallet/transactions/transfer-funds
        Body: {
            funding_public_keys: [ZkPublicKey],
            recipient_public_key: ZkPublicKey,
            change_public_key: ZkPublicKey,
            amount: Value,
        }
        """
        if self._mock:
            import secrets
            return {
                "tx_hash": "0x" + secrets.token_hex(32),
                "amount": amount,
                "recipient": recipient,
                "mock": True,
            }

        try:
            async with httpx.AsyncClient() as client:
                resp = await client.post(
                    f"{self.node_url}/wallet/transactions/transfer-funds",
                    json={
                        "funding_public_keys": [funding_key] if funding_key else [],
                        "recipient_public_key": recipient,
                        "change_public_key": change_key or funding_key,
                        "amount": int(amount) if amount.isdigit() else amount,
                    },
                    timeout=30.0,
                )
                resp.raise_for_status()
                return resp.json()
        except Exception as e:
            return {"tx_hash": "", "error": str(e)}

    async def query_program(self, program_id: str, params: dict = None) -> dict:
        """Read LEZ program state (no state change)."""
        if self._mock:
            return {"program_id": program_id, "state": {}, "mock": True}

        try:
            async with httpx.AsyncClient() as client:
                resp = await client.post(
                    f"{self.node_url}/program/{program_id}/query",
                    json=params or {},
                    timeout=15.0,
                )
                resp.raise_for_status()
                return resp.json()
        except Exception as e:
            return {"program_id": program_id, "error": str(e)}

    async def call_program(self, program_id: str, instruction: str,
                           params: dict = None) -> dict:
        """Submit a LEZ program transaction (state change)."""
        if self._mock:
            import secrets
            return {
                "tx_hash": "0x" + secrets.token_hex(32),
                "program_id": program_id,
                "instruction": instruction,
                "mock": True,
            }

        try:
            async with httpx.AsyncClient() as client:
                resp = await client.post(
                    f"{self.node_url}/program/{program_id}/call",
                    json={"instruction": instruction, "params": params or {}},
                    timeout=30.0,
                )
                resp.raise_for_status()
                return resp.json()
        except Exception as e:
            return {"tx_hash": "", "error": str(e)}

    async def deploy_program(self, binary_path: str) -> dict:
        """Deploy a compiled LEZ program binary."""
        if self._mock:
            import secrets
            return {
                "program_id": "0x" + secrets.token_hex(20),
                "tx_hash": "0x" + secrets.token_hex(32),
                "mock": True,
            }

        try:
            with open(binary_path, "rb") as f:
                binary = f.read()
            async with httpx.AsyncClient() as client:
                resp = await client.post(
                    f"{self.node_url}/program/deploy",
                    content=binary,
                    headers={"Content-Type": "application/octet-stream"},
                    timeout=60.0,
                )
                resp.raise_for_status()
                return resp.json()
        except Exception as e:
            return {"program_id": "", "error": str(e)}
