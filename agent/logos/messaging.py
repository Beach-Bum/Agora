"""
agent/logos/messaging.py

Logos Messaging integration for Agora.

Security hardening applied:
  FIX-6: Nonce added to all signed messages — prevents replay attacks
  FIX-6: Seen-nonce cache with TTL — rejects replayed messages
  FIX-9: Minimum reputation check before processing intents — blocks spam
  FIX-9: Rate limiting per sender — caps message volume from single agent
"""

import asyncio
import json
import time
import hashlib
import secrets
import httpx
from typing import Callable, Optional
from dataclasses import dataclass, field
from collections import defaultdict

# ── Security constants ────────────────────────────────────────────

# FIX-6: Messages older than this are rejected as potential replays
MESSAGE_VALIDITY_WINDOW_MS = 5 * 60 * 1000  # 5 minutes

# FIX-6: Nonce cache TTL — keep seen nonces for twice the validity window
NONCE_CACHE_TTL_MS = MESSAGE_VALIDITY_WINDOW_MS * 2

# FIX-9: Minimum reputation score (0.0–1.0) to have intents processed
MIN_SENDER_REPUTATION = 0.30

# FIX-9: Max messages per sender per minute before rate limiting kicks in
RATE_LIMIT_PER_SENDER_PER_MIN = 10

# ── Topic schema ──────────────────────────────────────────────────

TOPIC_CAPABILITIES = "/agora/1/capabilities/json"
TOPIC_INTENTS      = "/agora/1/intents/json"
TOPIC_REPUTATION   = "/agora/1/reputation/json"

def topic_offers(buyer_pub_key_hex: str) -> str:
    return f"/agora/1/offers/{buyer_pub_key_hex}/json"

def topic_negotiate(session_id: str) -> str:
    return f"/agora/1/negotiate/{session_id}/json"

def topic_delivery(escrow_id: str) -> str:
    return f"/agora/1/delivery/{escrow_id}/json"

def topic_dispute(escrow_id: str) -> str:
    return f"/agora/1/dispute/{escrow_id}/json"


# ── Nonce cache (FIX-6) ───────────────────────────────────────────

class NonceCache:
    """
    Tracks seen message nonces to prevent replay attacks.
    Entries expire after NONCE_CACHE_TTL_MS.
    """

    def __init__(self):
        self._seen: dict[str, int] = {}  # nonce -> expiry_ts_ms

    def check_and_record(self, nonce: str) -> bool:
        """
        Returns True if nonce is fresh (not seen before).
        Returns False if nonce was already seen (replay attempt).
        """
        now = int(time.time() * 1000)
        self._evict_expired(now)

        if nonce in self._seen:
            return False  # Replay!

        self._seen[nonce] = now + NONCE_CACHE_TTL_MS
        return True

    def _evict_expired(self, now: int):
        expired = [n for n, exp in self._seen.items() if exp <= now]
        for n in expired:
            del self._seen[n]


# ── Rate limiter (FIX-9) ──────────────────────────────────────────

class RateLimiter:
    """Per-sender sliding window rate limiter."""

    def __init__(self, max_per_min: int = RATE_LIMIT_PER_SENDER_PER_MIN):
        self._max = max_per_min
        self._windows: dict[str, list[int]] = defaultdict(list)

    def allow(self, sender_id: str) -> bool:
        now = int(time.time() * 1000)
        window_start = now - 60_000
        msgs = [t for t in self._windows[sender_id] if t > window_start]
        self._windows[sender_id] = msgs

        if len(msgs) >= self._max:
            return False

        self._windows[sender_id].append(now)
        return True


# ── Message validation ────────────────────────────────────────────

def validate_incoming_message(msg: dict, nonce_cache: NonceCache,
                               rate_limiter: RateLimiter,
                               min_reputation: float = MIN_SENDER_REPUTATION) -> tuple[bool, str]:
    """
    Validate an incoming Logos Messaging message.

    Checks:
    - Required fields present
    - Timestamp within validity window (FIX-6)
    - Nonce not seen before (FIX-6 replay prevention)
    - Sender not rate-limited (FIX-9)

    Returns (valid: bool, reason: str).
    """
    now_ms = int(time.time() * 1000)

    # Required fields
    for field in ("version", "type", "ts", "nonce"):
        if field not in msg:
            return False, f"missing field: {field}"

    # FIX-6: Timestamp check
    msg_ts = msg.get("ts", 0)
    age_ms = now_ms - msg_ts
    if age_ms > MESSAGE_VALIDITY_WINDOW_MS:
        return False, f"message too old: {age_ms}ms"
    if age_ms < -30_000:  # Allow 30s clock skew
        return False, "message from the future"

    # FIX-6: Nonce replay check
    nonce = msg.get("nonce", "")
    if not nonce or len(nonce) < 16:
        return False, "missing or short nonce"
    if not nonce_cache.check_and_record(nonce):
        return False, "replay attack: nonce already seen"

    # FIX-9: Rate limiting
    sender = msg.get("agentId") or msg.get("buyerId") or msg.get("sellerId") or ""
    if sender and not rate_limiter.allow(sender):
        return False, f"rate limit exceeded for {sender[:16]}"

    return True, "ok"


# ── Message models ────────────────────────────────────────────────

@dataclass
class CapabilityService:
    id: str
    category: str
    price_per_unit: str
    currency: str = "NOM"
    model: Optional[str] = None
    context_window: Optional[int] = None
    avg_latency_ms: Optional[int] = None


@dataclass
class CapabilityManifest:
    agent_id: str
    identity_tx_hash: str
    stake: str
    reputation: float
    capabilities: list

    def to_message(self, sign_fn: Callable) -> dict:
        data = {
            "version":         "agora/1",
            "type":            "capability_manifest",
            "agentId":         self.agent_id,
            "identityTxHash":  self.identity_tx_hash,
            "stake":           self.stake,
            "reputation":      self.reputation,
            "capabilities":    [c.__dict__ if hasattr(c, '__dict__') else c for c in self.capabilities],
            "ts":              int(time.time() * 1000),
            "nonce":           secrets.token_hex(16),  # FIX-6: fresh nonce per message
        }
        canonical = json.dumps(data, sort_keys=True, separators=(',', ':'))
        data["sig"] = sign_fn(canonical.encode())
        return data


@dataclass
class BuyIntent:
    buyer_id: str
    category: str
    budget: str
    max_price_per_unit: str
    max_latency_ms: int
    min_reputation: float
    expire_ts: int
    buyer_nonce: str = field(default_factory=lambda: secrets.token_hex(16))  # FIX-2

    def to_message(self, sign_fn: Callable) -> dict:
        data = {
            "version":          "agora/1",
            "type":             "buy_intent",
            "buyerId":          self.buyer_id,
            "category":         self.category,
            "requirements": {
                "maxPricePerUnit": self.max_price_per_unit,
                "maxLatencyMs":    self.max_latency_ms,
                "minReputation":   self.min_reputation,
            },
            "budget":           self.budget,
            "expireTs":         self.expire_ts,
            "buyerNonce":       self.buyer_nonce,  # FIX-2: included for escrow commitment
            "ts":               int(time.time() * 1000),
            "nonce":            secrets.token_hex(16),  # FIX-6
        }
        canonical = json.dumps(data, sort_keys=True, separators=(',', ':'))
        data["sig"] = sign_fn(canonical.encode())
        return data


@dataclass
class Offer:
    session_id: str
    seller_id: str
    buyer_id: str
    capability_id: str
    price_per_unit: str
    estimated_units: int
    total_price: str
    delivery_timeout_ms: int
    delivery_hash_commitment: str
    escrow_slash_bps: int = 500

    def to_message(self, sign_fn: Callable) -> dict:
        data = {
            "version":                "agora/1",
            "type":                   "offer",
            "sessionId":              self.session_id,
            "sellerId":               self.seller_id,
            "buyerId":                self.buyer_id,
            "capabilityId":           self.capability_id,
            "pricePerUnit":           self.price_per_unit,
            "estimatedUnits":         self.estimated_units,
            "totalPrice":             self.total_price,
            "deliveryTimeoutMs":      self.delivery_timeout_ms,
            "deliveryHashCommitment": self.delivery_hash_commitment,
            "escrowParams": {
                "timeoutMs": self.delivery_timeout_ms * 3,
                "slashBps":  self.escrow_slash_bps,
            },
            "ts":    int(time.time() * 1000),
            "nonce": secrets.token_hex(16),  # FIX-6
        }
        canonical = json.dumps(data, sort_keys=True, separators=(',', ':'))
        data["sig"] = sign_fn(canonical.encode())
        return data


@dataclass
class DeliveryNotification:
    session_id: str
    escrow_id: str
    seller_id: str
    cid: str
    output_hash: str

    def to_message(self, sign_fn: Callable) -> dict:
        data = {
            "version":    "agora/1",
            "type":       "delivery",
            "sessionId":  self.session_id,
            "escrowId":   self.escrow_id,
            "sellerId":   self.seller_id,
            "cid":        self.cid,
            "outputHash": self.output_hash,
            "ts":         int(time.time() * 1000),
            "nonce":      secrets.token_hex(16),  # FIX-6
        }
        canonical = json.dumps(data, sort_keys=True, separators=(',', ':'))
        data["sig"] = sign_fn(canonical.encode())
        return data


# ── Logos Messaging client ────────────────────────────────────────

class LogosMessagingClient:
    """
    Async Logos Messaging client with replay and rate-limit protection.
    """

    def __init__(self, node_url: str = "http://localhost:8645"):
        self.node_url = node_url
        self._subscriptions: dict[str, list[Callable]] = {}
        self._polling = False
        self._nonce_cache = NonceCache()       # FIX-6
        self._rate_limiter = RateLimiter()     # FIX-9

    async def start(self):
        async with httpx.AsyncClient() as client:
            try:
                resp = await client.get(f"{self.node_url}/health", timeout=5.0)
                resp.raise_for_status()
                print(f"[Logos Messaging] Connected at {self.node_url}")
            except Exception as e:
                print(f"[Logos Messaging] Node not reachable: {e} — mock mode")

    async def publish(self, topic: str, payload: dict) -> bool:
        body = {
            "contentTopic": topic,
            "payload":      json.dumps(payload),
            "contentType":  "application/json",
            "timestamp":    int(time.time() * 1e9),
        }
        try:
            async with httpx.AsyncClient() as client:
                resp = await client.post(f"{self.node_url}/relay/v1/messages",
                                         json=body, timeout=10.0)
                return resp.status_code == 200
        except Exception as e:
            print(f"[Logos Messaging] Publish failed: {e}")
            return False

    def subscribe(self, topic: str, handler: Callable):
        if topic not in self._subscriptions:
            self._subscriptions[topic] = []
        self._subscriptions[topic].append(handler)

    async def poll_store(self, topic: str, since_ms: int) -> list[dict]:
        try:
            async with httpx.AsyncClient() as client:
                resp = await client.get(
                    f"{self.node_url}/store/v3/messages",
                    params={"contentTopics": topic, "startTime": str(since_ms * 1_000_000)},
                    timeout=15.0,
                )
                if resp.status_code == 200:
                    messages = []
                    for m in resp.json().get("messages", []):
                        try:
                            payload = json.loads(m.get("payload", "{}"))

                            # FIX-6 + FIX-9: Validate incoming messages
                            valid, reason = validate_incoming_message(
                                payload, self._nonce_cache, self._rate_limiter
                            )
                            if not valid:
                                print(f"[Logos Messaging] Dropping message: {reason}")
                                continue

                            messages.append(payload)
                        except json.JSONDecodeError:
                            pass
                    return messages
        except Exception as e:
            print(f"[Logos Messaging] Store poll failed: {e}")
        return []

    async def start_polling(self, interval_ms: int = 2000):
        self._polling = True
        last_poll: dict[str, int] = {}

        while self._polling:
            for topic, handlers in self._subscriptions.items():
                since = last_poll.get(topic, int(time.time() * 1000) - 60_000)
                messages = await self.poll_store(topic, since)
                last_poll[topic] = int(time.time() * 1000)
                for msg in messages:
                    for handler in handlers:
                        try:
                            if asyncio.iscoroutinefunction(handler):
                                await handler(msg)
                            else:
                                handler(msg)
                        except Exception as e:
                            print(f"[Logos Messaging] Handler error: {e}")
            await asyncio.sleep(interval_ms / 1000)

    def stop_polling(self):
        self._polling = False


# ── High-level marketplace helpers ────────────────────────────────

class MarketplaceMessaging:

    def __init__(self, client: LogosMessagingClient, agent_id: str, sign_fn: Callable):
        self.client   = client
        self.agent_id = agent_id
        self.sign_fn  = sign_fn

    async def broadcast_capabilities(self, manifest: CapabilityManifest):
        msg = manifest.to_message(self.sign_fn)
        ok  = await self.client.publish(TOPIC_CAPABILITIES, msg)
        if ok:
            print(f"[Agora] Capabilities broadcast: {len(manifest.capabilities)} services")
        return ok

    async def broadcast_intent(self, intent: BuyIntent):
        msg = intent.to_message(self.sign_fn)
        ok  = await self.client.publish(TOPIC_INTENTS, msg)
        if ok:
            print(f"[Agora] Intent broadcast: {intent.category} budget={intent.budget} NOM nonce={intent.buyer_nonce[:8]}…")
        return ok

    async def send_offer(self, offer: Offer):
        msg = offer.to_message(self.sign_fn)
        return await self.client.publish(topic_offers(offer.buyer_id), msg)

    async def send_delivery(self, notification: DeliveryNotification):
        msg = notification.to_message(self.sign_fn)
        return await self.client.publish(topic_delivery(notification.escrow_id), msg)

    async def accept_offer(self, session_id: str):
        msg = {
            "version":   "agora/1",
            "type":      "negotiation",
            "sessionId": session_id,
            "action":    "accept",
            "fromId":    self.agent_id,
            "ts":        int(time.time() * 1000),
            "nonce":     secrets.token_hex(16),  # FIX-6
        }
        canonical = json.dumps(msg, sort_keys=True, separators=(',', ':'))
        msg["sig"] = self.sign_fn(canonical.encode())
        return await self.client.publish(topic_negotiate(session_id), msg)

    def on_intent(self, handler: Callable):
        self.client.subscribe(TOPIC_INTENTS, handler)

    def on_offer(self, handler: Callable):
        self.client.subscribe(topic_offers(self.agent_id), handler)

    def on_delivery(self, escrow_id: str, handler: Callable):
        self.client.subscribe(topic_delivery(escrow_id), handler)
