"""
agent/core/owner_channel.py

E2E encrypted owner communication channel via Logos Messaging.

LP-0008 requirement: Agent maintains dedicated, end-to-end encrypted
Logos Messaging topic with owner. Owner can reach agent from any
Logos app instance holding owner's keys.

The owner channel supports:
  - Real-time chat between owner and agent
  - Above-threshold transaction approval requests
  - Configuration changes
  - Skill invocation
  - Status notifications
"""

import json
import time
import asyncio
import secrets
from dataclasses import dataclass, field
from typing import Optional, Callable, Awaitable

from agent.logos.messaging import LogosMessagingClient
from agent.core.daemon_wallet import DaemonWallet


@dataclass
class ApprovalRequest:
    """A pending transaction that needs owner approval."""
    request_id: str
    action: str              # "wallet.send", "program.call", etc.
    amount: float
    recipient: str
    description: str
    created_at: float
    timeout_s: float = 300.0  # 5 minute default timeout
    approved: Optional[bool] = None
    responded_at: Optional[float] = None

    @property
    def expired(self) -> bool:
        return time.time() > self.created_at + self.timeout_s

    def to_dict(self) -> dict:
        return {
            "request_id": self.request_id,
            "action": self.action,
            "amount": self.amount,
            "recipient": self.recipient,
            "description": self.description,
            "created_at": self.created_at,
            "timeout_s": self.timeout_s,
            "expired": self.expired,
            "approved": self.approved,
        }


class OwnerChannel:
    """
    E2E encrypted channel between agent and owner via Logos Messaging.

    Messages are structured as JSON with a "type" field:
      - "chat": regular chat message
      - "approval_request": agent asking owner to approve a transaction
      - "approval_response": owner approving/denying a request
      - "notification": agent sending a status update
      - "command": owner sending a command (skill invocation, config change)
    """

    def __init__(self, messaging: LogosMessagingClient, wallet: DaemonWallet,
                 agent_pub_key: str, owner_pub_key: str):
        self._messaging = messaging
        self._wallet = wallet
        self._agent_pub_key = agent_pub_key
        self._owner_pub_key = owner_pub_key
        self._topic_id: Optional[str] = None
        self._pending_approvals: dict[str, ApprovalRequest] = {}
        self._approval_events: dict[str, asyncio.Event] = {}
        self._message_handlers: list[Callable] = []
        self._running = False

    @property
    def topic_id(self) -> Optional[str]:
        return self._topic_id

    async def initialize(self) -> str:
        """
        Create or join the dedicated E2E encrypted topic with the owner.
        Topic ID is derived from agent + owner public keys for determinism.
        """
        import hashlib
        # Deterministic topic: hash(sort(agent_key, owner_key))
        keys = sorted([self._agent_pub_key, self._owner_pub_key])
        topic_seed = f"agora-owner-channel:{keys[0]}:{keys[1]}"
        self._topic_id = hashlib.sha256(topic_seed.encode()).hexdigest()[:32]

        # Join the encrypted topic
        await self._messaging.join_encrypted_topic(
            self._topic_id,
            [self._agent_pub_key, self._owner_pub_key],
        )

        return self._topic_id

    def on_message(self, handler: Callable) -> None:
        """Register a handler for incoming owner messages."""
        self._message_handlers.append(handler)

    async def start(self) -> None:
        """Start listening for messages on the owner channel."""
        if not self._topic_id:
            await self.initialize()
        self._running = True

        # Send online notification
        await self.notify("Agent is online", level="info")

    async def stop(self) -> None:
        """Stop the owner channel."""
        self._running = False
        await self.notify("Agent going offline", level="info")

    # ── Sending Messages ────────────────────────────────────────

    async def send_chat(self, message: str) -> None:
        """Send a chat message to the owner."""
        await self._send({
            "type": "chat",
            "content": message,
            "from": "agent",
            "ts": time.time(),
        })

    async def notify(self, message: str, level: str = "info", data: dict = None) -> None:
        """Send a notification to the owner."""
        msg = {
            "type": "notification",
            "level": level,
            "content": message,
            "from": "agent",
            "ts": time.time(),
        }
        if data:
            msg["data"] = data
        await self._send(msg)

    async def request_approval(self, action: str, amount: float,
                                recipient: str, description: str,
                                timeout_s: float = 300.0) -> bool:
        """
        Request owner approval for an above-threshold transaction.

        Returns True if approved, False if denied or timed out.
        The agent MUST NOT execute the transaction if this returns False.
        On notification failure, retries before timing out.
        """
        request_id = secrets.token_hex(8)
        request = ApprovalRequest(
            request_id=request_id,
            action=action,
            amount=amount,
            recipient=recipient,
            description=description,
            created_at=time.time(),
            timeout_s=timeout_s,
        )
        self._pending_approvals[request_id] = request
        event = asyncio.Event()
        self._approval_events[request_id] = event

        # Send approval request to owner with retry
        approval_msg = {
            "type": "approval_request",
            "request_id": request_id,
            "action": action,
            "amount": amount,
            "recipient": recipient,
            "description": description,
            "timeout_s": timeout_s,
            "from": "agent",
            "ts": time.time(),
        }

        retries = 3
        for attempt in range(retries):
            try:
                await self._send(approval_msg)
                break
            except Exception as e:
                if attempt == retries - 1:
                    # Failed to notify owner — do NOT execute
                    await self.notify(
                        f"FAILED to reach owner for approval of {action} "
                        f"({amount} NOM to {recipient[:16]}...). Transaction NOT executed.",
                        level="error",
                    )
                    self._cleanup_approval(request_id)
                    return False
                await asyncio.sleep(2 ** attempt)

        # Wait for response or timeout
        try:
            await asyncio.wait_for(event.wait(), timeout=timeout_s)
        except asyncio.TimeoutError:
            await self.notify(
                f"Approval request {request_id} timed out after {timeout_s}s. "
                f"Transaction NOT executed.",
                level="warning",
            )
            self._cleanup_approval(request_id)
            return False

        approved = request.approved
        self._cleanup_approval(request_id)
        return approved is True

    def handle_approval_response(self, request_id: str, approved: bool) -> None:
        """Handle an approval response from the owner."""
        request = self._pending_approvals.get(request_id)
        if not request:
            return
        request.approved = approved
        request.responded_at = time.time()
        event = self._approval_events.get(request_id)
        if event:
            event.set()

    async def handle_incoming(self, raw_message: str) -> None:
        """Process an incoming message from the owner."""
        try:
            msg = json.loads(raw_message)
        except json.JSONDecodeError:
            return

        msg_type = msg.get("type", "")

        if msg_type == "approval_response":
            self.handle_approval_response(
                msg.get("request_id", ""),
                msg.get("approved", False),
            )
        elif msg_type == "command":
            # Dispatch to registered handlers
            for handler in self._message_handlers:
                try:
                    await handler(msg)
                except Exception:
                    pass
        elif msg_type == "chat":
            for handler in self._message_handlers:
                try:
                    await handler(msg)
                except Exception:
                    pass

    def pending_approvals(self) -> list[dict]:
        """List pending approval requests."""
        return [r.to_dict() for r in self._pending_approvals.values() if not r.expired]

    def _cleanup_approval(self, request_id: str) -> None:
        self._pending_approvals.pop(request_id, None)
        self._approval_events.pop(request_id, None)

    async def _send(self, msg: dict) -> None:
        """Send a structured message on the owner channel."""
        if self._topic_id:
            await self._messaging.send_to_topic(
                self._topic_id,
                json.dumps(msg),
            )
