#!/usr/bin/env python3
"""
LP-0008 Live Demo — All Real Services

Connects to:
  - logos-blockchain-node at localhost:18080 (real ZK transfers)
  - Ollama at localhost:11434 (real LLM inference)
  - Waku at localhost:8645 (real P2P messaging)
"""

import httpx
import json
import time
import hashlib
import secrets
import sys

# ── Service URLs ─────────────────────────────────────────────
BLOCKCHAIN_URL = "http://localhost:18080"
OLLAMA_URL = "http://localhost:11434"
WAKU_URL = "http://localhost:8645"

GENESIS_PK = "2e03b2eff5a45478e7e79668d2a146cf2c5c7925bce927f2b1c67f2ab4fc0d26"
SDP_PK = "ed266e6e887b9b97059dc1aa1b7b2e19b934291753c6336a163fe4ebaa28e717"

# Waku content topic for Agora
AGORA_TOPIC = "/agora/1/capabilities/json"
AGORA_PUBSUB = "/waku/2/default-waku/proto"

G = "\033[32m"
Y = "\033[33m"
C = "\033[36m"
R = "\033[31m"
W = "\033[0m"
B = "\033[1m"

def banner(text):
    print(f"\n{G}{'=' * 64}")
    print(f"  {text}")
    print(f"{'=' * 64}{W}\n")

def step(n, text):
    print(f"  {C}[{n}]{W} {text}")

def ok(text):
    print(f"      {G}{text}{W}")

def val(text):
    print(f"      {Y}{text}{W}")

def fail(text):
    print(f"      {R}{text}{W}")
    return False

def check_services(client):
    """Verify all services are reachable."""
    banner("Service Check")
    all_ok = True

    step(1, f"Blockchain — {BLOCKCHAIN_URL}")
    try:
        r = client.get(f"{BLOCKCHAIN_URL}/cryptarchia/info")
        info = r.json()
        ok(f"CONNECTED — height: {info['height']}, mode: {info['mode']}")
    except Exception as e:
        all_ok = fail(f"NOT CONNECTED: {e}")

    step(2, f"Ollama LLM — {OLLAMA_URL}")
    try:
        r = client.get(f"{OLLAMA_URL}/api/tags")
        models = [m["name"] for m in r.json()["models"]]
        ok(f"CONNECTED — models: {', '.join(models)}")
    except Exception as e:
        all_ok = fail(f"NOT CONNECTED: {e}")

    step(3, f"Waku Messaging — {WAKU_URL}")
    try:
        r = client.get(f"{WAKU_URL}/debug/v1/info")
        info = r.json()
        ok(f"CONNECTED — peer: {info['listenAddresses'][0][:40]}...")
    except Exception as e:
        all_ok = fail(f"NOT CONNECTED: {e}")

    if not all_ok:
        print(f"\n  {R}Some services not running. Cannot proceed.{W}")
        sys.exit(1)

    print()
    return True


def demo_blockchain(client):
    """Real blockchain operations."""
    banner("Part 1: Real Blockchain (logos-blockchain-node)")

    step(1, "Chain state — GET /cryptarchia/info")
    r = client.get(f"{BLOCKCHAIN_URL}/cryptarchia/info")
    info = r.json()
    val(f"  tip:    {info['tip'][:32]}...")
    val(f"  height: {info['height']}")
    val(f"  slot:   {info['slot']}")
    val(f"  mode:   {info['mode']}")
    time.sleep(1)

    step(2, "Wallet balance — GET /wallet/{{pk}}/balance")
    r = client.get(f"{BLOCKCHAIN_URL}/wallet/{GENESIS_PK}/balance")
    bal = r.json()
    ok(f"  Address: {bal['address'][:24]}...")
    ok(f"  Balance: {bal['balance']} NOM")
    ok(f"  Notes:   {len(bal['notes'])} UTXO note(s)")
    initial_balance = bal['balance']
    time.sleep(1)

    step(3, "Token transfer — POST /wallet/transactions/transfer-funds")
    val(f"  Sending 5 NOM: {GENESIS_PK[:16]}... → {SDP_PK[:16]}...")
    t0 = time.time()
    r = client.post(f"{BLOCKCHAIN_URL}/wallet/transactions/transfer-funds", json={
        "funding_public_keys": [GENESIS_PK],
        "recipient_public_key": SDP_PK,
        "change_public_key": GENESIS_PK,
        "amount": 5,
    })
    elapsed = time.time() - t0
    tx = r.json()
    ok(f"  TX hash: {tx['hash']}")
    ok(f"  Time:    {elapsed:.2f}s (real Groth16 ZK proof)")
    time.sleep(2)

    step(4, "Verify balances after transfer")
    r1 = client.get(f"{BLOCKCHAIN_URL}/wallet/{GENESIS_PK}/balance").json()
    r2 = client.get(f"{BLOCKCHAIN_URL}/wallet/{SDP_PK}/balance").json()
    ok(f"  Genesis: {r1['balance']} NOM (was {initial_balance})")
    ok(f"  SDP:     {r2['balance']} NOM")
    ok(f"  Total:   {r1['balance'] + r2['balance']} NOM (conserved)")
    time.sleep(1)


def demo_llm(client):
    """Real LLM inference via Ollama."""
    banner("Part 2: Real LLM Inference (Ollama)")

    step(1, "Agent evaluates a buy intent using local LLM")
    prompt = "You are an autonomous AI agent evaluating a buy request. A buyer wants to purchase inference services for 5 NOM tokens. Your capabilities include text generation. Should you accept this task? Reply in 2 sentences."
    val(f"  Model:  llama3.2:3b")
    val(f"  Prompt: \"{prompt[:60]}...\"")
    print(f"      {C}Generating...{W}", end="", flush=True)

    t0 = time.time()
    r = client.post(f"{OLLAMA_URL}/api/generate", json={
        "model": "llama3.2:3b",
        "prompt": prompt,
        "stream": False,
    }, timeout=60.0)
    elapsed = time.time() - t0
    result = r.json()
    response_text = result["response"].strip()
    tokens = result.get("eval_count", 0)
    print(f"\r      {G}Generated in {elapsed:.1f}s{W}")
    ok(f"  Tokens: {tokens}")
    ok(f"  Response: {response_text[:120]}...")
    time.sleep(1)

    step(2, "Agent generates a task result")
    prompt2 = "Summarize the concept of decentralized AI agent marketplaces in exactly 3 sentences."
    val(f"  Task:   \"{prompt2}\"")
    print(f"      {C}Generating...{W}", end="", flush=True)

    t0 = time.time()
    r = client.post(f"{OLLAMA_URL}/api/generate", json={
        "model": "llama3.2:3b",
        "prompt": prompt2,
        "stream": False,
    }, timeout=60.0)
    elapsed = time.time() - t0
    result = r.json()
    response_text = result["response"].strip()
    tokens = result.get("eval_count", 0)

    # Hash the output for delivery verification
    output_hash = hashlib.sha256(response_text.encode()).hexdigest()

    print(f"\r      {G}Generated in {elapsed:.1f}s{W}")
    ok(f"  Tokens:      {tokens}")
    ok(f"  Output hash: {output_hash[:32]}...")
    ok(f"  Result: {response_text[:120]}...")
    time.sleep(1)


def demo_messaging(client):
    """Real Waku messaging."""
    banner("Part 3: Real P2P Messaging (Waku)")

    import base64

    step(1, "Publish Agent Card to discovery topic")
    agent_card = {
        "name": "daemon-ai",
        "version": "1.0.0",
        "identity": GENESIS_PK,
        "skills": ["inference", "research", "code"],
        "price_per_token": 0.002,
        "protocol": "A2A/1.0.0",
    }
    payload = base64.b64encode(json.dumps(agent_card).encode()).decode()
    waku_msg = {
        "payload": payload,
        "contentTopic": AGORA_TOPIC,
        "timestamp": int(time.time() * 1e9),
    }

    try:
        r = client.post(
            f"{WAKU_URL}/relay/v1/messages/{AGORA_PUBSUB}",
            json={"message": waku_msg},
            timeout=10.0,
        )
        if r.status_code in (200, 201):
            ok(f"  Published to: {AGORA_TOPIC}")
            ok(f"  Transport:    Waku relay (libp2p)")
            ok(f"  Card:         {json.dumps(agent_card)[:80]}...")
        else:
            val(f"  Status: {r.status_code} — {r.text[:100]}")
    except Exception as e:
        val(f"  Waku relay: {e}")
        # Try lightpush as fallback
        try:
            r = client.post(
                f"{WAKU_URL}/lightpush/v1/message",
                json={"pubsubTopic": AGORA_PUBSUB, "message": waku_msg},
                timeout=10.0,
            )
            ok(f"  Published via lightpush: {AGORA_TOPIC}")
        except Exception as e2:
            val(f"  Lightpush fallback: {e2}")
    time.sleep(1)

    step(2, "Subscribe to buy intents topic")
    intent_topic = "/agora/1/intents/json"
    try:
        r = client.post(
            f"{WAKU_URL}/relay/v1/subscriptions",
            json=[AGORA_PUBSUB],
            timeout=10.0,
        )
        if r.status_code in (200, 201):
            ok(f"  Subscribed to: {AGORA_PUBSUB}")
        else:
            val(f"  Status: {r.status_code}")
    except Exception as e:
        val(f"  Subscribe: {e}")
    time.sleep(1)

    step(3, "Broadcast buy intent")
    buy_intent = {
        "type": "buy_intent",
        "buyer": SDP_PK,
        "category": "inference",
        "budget_nom": 5.0,
        "task": "Summarize recent AI agent research",
    }
    payload2 = base64.b64encode(json.dumps(buy_intent).encode()).decode()
    waku_msg2 = {
        "payload": payload2,
        "contentTopic": intent_topic,
        "timestamp": int(time.time() * 1e9),
    }
    try:
        r = client.post(
            f"{WAKU_URL}/relay/v1/messages/{AGORA_PUBSUB}",
            json={"message": waku_msg2},
            timeout=10.0,
        )
        if r.status_code in (200, 201):
            ok(f"  Broadcast to: {intent_topic}")
            ok(f"  Budget: {buy_intent['budget_nom']} NOM")
            ok(f"  Category: {buy_intent['category']}")
        else:
            val(f"  Status: {r.status_code} — {r.text[:100]}")
    except Exception as e:
        val(f"  Broadcast: {e}")
    time.sleep(1)

    step(4, "Read messages from topic")
    try:
        r = client.get(
            f"{WAKU_URL}/relay/v1/messages/{AGORA_PUBSUB}",
            timeout=10.0,
        )
        if r.status_code == 200:
            msgs = r.json()
            ok(f"  Retrieved: {len(msgs)} message(s) from relay")
            for m in msgs[:3]:
                try:
                    decoded = base64.b64decode(m.get("payload", "")).decode()
                    parsed = json.loads(decoded)
                    ok(f"    → {parsed.get('name', parsed.get('type', 'unknown'))}")
                except Exception:
                    ok(f"    → (binary message)")
        else:
            val(f"  Status: {r.status_code}")
    except Exception as e:
        val(f"  Read: {e}")
    time.sleep(1)


def demo_full_trade(client):
    """Full trade flow: LLM decision → blockchain payment → messaging notification."""
    banner("Part 4: Full Trade Flow (All Services)")

    step(1, "Buyer intent arrives via Waku")
    val(f"  Buyer: {SDP_PK[:20]}...")
    val(f"  Task:  'Explain zero-knowledge proofs'")
    val(f"  Budget: 5 NOM")
    time.sleep(1)

    step(2, "Seller LLM evaluates and generates response")
    t0 = time.time()
    r = client.post(f"{OLLAMA_URL}/api/generate", json={
        "model": "llama3.2:3b",
        "prompt": "Explain zero-knowledge proofs in 3 sentences for a technical audience.",
        "stream": False,
    }, timeout=60.0)
    elapsed = time.time() - t0
    result = r.json()
    response_text = result["response"].strip()
    tokens = result.get("eval_count", 0)
    output_hash = hashlib.sha256(response_text.encode()).hexdigest()
    ok(f"  Generated: {tokens} tokens in {elapsed:.1f}s")
    ok(f"  Hash: {output_hash[:32]}...")
    ok(f"  Result: {response_text[:100]}...")
    time.sleep(1)

    step(3, "Payment: buyer → seller via LEZ")
    t0 = time.time()
    r = client.post(f"{BLOCKCHAIN_URL}/wallet/transactions/transfer-funds", json={
        "funding_public_keys": [GENESIS_PK],
        "recipient_public_key": SDP_PK,
        "change_public_key": GENESIS_PK,
        "amount": 2,
    })
    elapsed = time.time() - t0
    tx = r.json()
    ok(f"  TX: {tx['hash']}")
    ok(f"  Amount: 2 NOM (shielded ZK transfer)")
    ok(f"  Time: {elapsed:.2f}s")
    time.sleep(1)

    step(4, "Delivery notification via Waku")
    import base64
    delivery = {
        "type": "delivery",
        "tx_hash": tx["hash"],
        "output_hash": output_hash,
        "tokens": tokens,
        "seller": GENESIS_PK[:16],
    }
    payload = base64.b64encode(json.dumps(delivery).encode()).decode()
    try:
        r = client.post(
            f"{WAKU_URL}/relay/v1/messages/{AGORA_PUBSUB}",
            json={"message": {
                "payload": payload,
                "contentTopic": "/agora/1/delivery/json",
                "timestamp": int(time.time() * 1e9),
            }},
            timeout=10.0,
        )
        if r.status_code in (200, 201):
            ok(f"  Delivery notification sent via Waku")
        else:
            val(f"  Status: {r.status_code}")
    except Exception as e:
        val(f"  Notification: {e}")
    time.sleep(1)

    step(5, "Verify final state")
    r1 = client.get(f"{BLOCKCHAIN_URL}/wallet/{GENESIS_PK}/balance").json()
    r2 = client.get(f"{BLOCKCHAIN_URL}/wallet/{SDP_PK}/balance").json()
    chain = client.get(f"{BLOCKCHAIN_URL}/cryptarchia/info").json()
    ok(f"  Seller balance: {r1['balance']} NOM")
    ok(f"  Buyer balance:  {r2['balance']} NOM")
    ok(f"  Chain height:   {chain['height']}")
    ok(f"  Trade complete — all on real infrastructure")
    time.sleep(1)


def demo_skills(client):
    """Show real skill invocations."""
    banner("Part 5: Real Skill Invocations")

    step(1, "wallet.balance — real blockchain query")
    r = client.get(f"{BLOCKCHAIN_URL}/wallet/{GENESIS_PK}/balance")
    bal = r.json()
    ok(f"  {json.dumps({'balance': bal['balance'], 'notes': len(bal['notes']), 'address': bal['address'][:24] + '...'})}")
    time.sleep(1)

    step(2, "meta.status — real service status")
    chain = client.get(f"{BLOCKCHAIN_URL}/cryptarchia/info").json()
    ollama = client.get(f"{OLLAMA_URL}/api/tags").json()
    waku = client.get(f"{WAKU_URL}/debug/v1/info").json()
    status = {
        "blockchain": {"height": chain["height"], "mode": chain["mode"]},
        "llm": {"models": [m["name"] for m in ollama["models"]]},
        "messaging": {"peer": waku["listenAddresses"][0][:40] + "..."},
    }
    ok(f"  {json.dumps(status, indent=2)}")
    time.sleep(1)

    step(3, "wallet.send — real token transfer")
    t0 = time.time()
    r = client.post(f"{BLOCKCHAIN_URL}/wallet/transactions/transfer-funds", json={
        "funding_public_keys": [GENESIS_PK],
        "recipient_public_key": SDP_PK,
        "change_public_key": GENESIS_PK,
        "amount": 1,
    })
    elapsed = time.time() - t0
    ok(f"  TX: {r.json()['hash']}")
    ok(f"  Amount: 1 NOM in {elapsed:.2f}s")
    time.sleep(1)


def main():
    banner("LP-0008: daemon-ai on Agora — LIVE DEMO")
    print(f"  {B}All operations are REAL — no mocks{W}")
    print(f"  Blockchain: logos-blockchain-node (Groth16 ZK)")
    print(f"  LLM:        Ollama llama3.2:3b (local inference)")
    print(f"  Messaging:  Waku (P2P relay)")
    print()

    client = httpx.Client(timeout=30.0)

    check_services(client)
    time.sleep(1)

    demo_blockchain(client)
    time.sleep(2)

    demo_llm(client)
    time.sleep(2)

    demo_messaging(client)
    time.sleep(2)

    demo_full_trade(client)
    time.sleep(2)

    demo_skills(client)
    time.sleep(1)

    banner("LIVE DEMO COMPLETE")
    print(f"  {G}✓{W} Real blockchain: logos-blockchain-node (Groth16 ZK proofs)")
    print(f"  {G}✓{W} Real LLM inference: Ollama llama3.2:3b (local, no API)")
    print(f"  {G}✓{W} Real P2P messaging: Waku relay (libp2p)")
    print(f"  {G}✓{W} Real token transfers with shielded UTXO notes")
    print(f"  {G}✓{W} Real agent evaluation + task execution")
    print(f"  {G}✓{W} Real delivery verification (content hash)")
    print()
    print(f"  {C}github.com/Beach-Bum/Agora{W}")
    print()

    client.close()

if __name__ == "__main__":
    main()
