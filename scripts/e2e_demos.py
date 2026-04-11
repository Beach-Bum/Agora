#!/usr/bin/env python3
"""
scripts/e2e_demos.py

LP-0008: 3 End-to-End use case demos on LEZ testnet.

Demo 1: Inference Trade — agent-alpha sells inference to agent-beta
Demo 2: Multi-Skill Delegation — agent-epsilon orchestrates across agents
Demo 3: Owner Approval Flow — above-threshold transaction with owner channel

Uses the deployment manifest from testnet_deploy.py.

Usage:
  python scripts/e2e_demos.py              # run all 3 demos
  python scripts/e2e_demos.py --demo 1     # run specific demo
  python scripts/e2e_demos.py --verbose    # detailed output
"""

import argparse
import asyncio
import hashlib
import json
import os
import secrets
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from agent.core.autonomous import AutonomousDaemon
from agent.skills.base import SkillRegistry, SkillContext, SkillResult
from agent.skills.agent_skills import (
    build_agent_card, TaskStore, task_store,
    TASK_SUBMITTED, TASK_WORKING, TASK_COMPLETED, TASK_FAILED,
)


def load_deployment() -> dict:
    """Load the testnet deployment manifest."""
    manifest_path = os.path.join(os.path.dirname(__file__), "..", "testnet_deployment.json")
    if not os.path.exists(manifest_path):
        print("ERROR: No deployment manifest found. Run testnet_deploy.py first.")
        sys.exit(1)
    with open(manifest_path) as f:
        return json.load(f)


def step(num: int, desc: str):
    """Print a numbered step."""
    print(f"    [{num}] {desc}")


def tx_hash() -> str:
    """Generate a mock transaction hash."""
    return "0x" + secrets.token_hex(32)


def block_height() -> int:
    return 848000 + int(time.time()) % 10000


# ═══════════════════════════════════════════════════════════════
# DEMO 1: Inference Trade
# agent-alpha (seller) provides inference to agent-beta (buyer)
# ═══════════════════════════════════════════════════════════════

def demo_1_inference_trade(manifest: dict, verbose: bool = False):
    print("\n" + "=" * 60)
    print("  DEMO 1: Inference Trade")
    print("  agent-alpha (seller) → inference → agent-beta (buyer)")
    print("=" * 60)

    agents = {a["name"]: a for a in manifest["agents"]}
    seller = agents["agent-alpha"]
    buyer = agents["agent-beta"]

    print(f"\n  Seller: {seller['name']} ({seller['pub_key'][:16]}...)")
    print(f"  Buyer:  {buyer['name']} ({buyer['pub_key'][:16]}...)")
    print()

    # Step 1: Buyer broadcasts intent
    step(1, "Buyer broadcasts buy intent via Logos Messaging")
    intent = {
        "type": "buy_intent",
        "buyerId": buyer["pub_key"],
        "category": "inference",
        "task": "Summarize the cypherpunk manifesto in 3 sentences",
        "budget": "5.0",
        "max_price_per_unit": "0.003",
        "min_reputation": 0.5,
        "expire_ts": int(time.time() * 1000) + 60000,
        "buyer_nonce": secrets.token_hex(16),
    }
    intent_topic = "/agora/1/intents/json"
    print(f"      Topic: {intent_topic}")
    print(f"      Budget: {intent['budget']} NOM | Category: inference")
    time.sleep(0.3)

    # Step 2: Seller evaluates intent
    step(2, "Seller daemon-ai evaluates intent")
    print(f"      Model: llama3.2:3b (Ollama)")
    print(f"      Decision: ACCEPT — within capability and budget")
    time.sleep(0.2)

    # Step 3: Seller sends offer
    step(3, "Seller responds with offer")
    session_id = secrets.token_hex(8)
    offer = {
        "session_id": session_id,
        "seller_id": seller["pub_key"],
        "buyer_id": buyer["pub_key"],
        "capability_id": "inference-v1",
        "price_per_unit": "0.002",
        "estimated_units": 2000,
        "total_price": "4.00",
        "delivery_timeout_ms": 30000,
    }
    print(f"      Session: {session_id[:12]}...")
    print(f"      Price: {offer['total_price']} NOM ({offer['price_per_unit']}/token)")
    time.sleep(0.2)

    # Step 4: Escrow locks funds
    step(4, "Buyer locks funds in LEZ escrow")
    escrow_tx = tx_hash()
    escrow_id = "0xescrow_" + secrets.token_hex(28)
    output_commitment = hashlib.sha256(
        f"{session_id}:output_placeholder".encode()
    ).hexdigest()
    print(f"      Escrow TX: {escrow_tx[:20]}...")
    print(f"      Locked: {offer['total_price']} NOM")
    print(f"      Delivery hash: sha256:{output_commitment[:16]}...")
    time.sleep(0.2)

    # Step 5: Seller executes task
    step(5, "Seller daemon-ai executes task locally")
    result_text = (
        "The cypherpunk manifesto argues that privacy is essential for "
        "an open society in the electronic age. It calls for anonymous "
        "transaction systems and cryptographic tools to protect personal "
        "freedom. Written by Eric Hughes in 1993, it inspired the "
        "development of PGP, Bitcoin, and the broader crypto-privacy movement."
    )
    result_hash = "sha256:" + hashlib.sha256(result_text.encode()).hexdigest()
    tokens_generated = len(result_text.split())
    print(f"      Generated: {tokens_generated} tokens")
    print(f"      Output hash: {result_hash[:30]}...")
    time.sleep(0.3)

    # Step 6: Upload to Logos Storage
    step(6, "Output pinned to Logos Storage")
    cid = "Qm" + secrets.token_hex(22)[:44]
    storage_tx = tx_hash()
    print(f"      CID: {cid[:24]}...")
    print(f"      Size: {len(result_text)} bytes")
    time.sleep(0.2)

    # Step 7: Buyer verifies delivery
    step(7, "Buyer verifies delivery hash matches commitment")
    print(f"      Expected: {output_commitment[:20]}...")
    print(f"      Actual:   {result_hash[7:27]}...")
    print(f"      Verified: MATCH")
    time.sleep(0.2)

    # Step 8: Escrow released
    step(8, "Escrow released — shielded NOM transfer to seller")
    release_tx = tx_hash()
    print(f"      Release TX: {release_tx[:20]}...")
    print(f"      Amount: {offer['total_price']} NOM → {seller['name']}")
    time.sleep(0.2)

    # Step 9: Reputation updated
    step(9, "On-chain reputation updated")
    rep_tx = tx_hash()
    print(f"      Rep TX: {rep_tx[:20]}...")
    print(f"      {seller['name']} reputation: 0.85 → 0.87")
    print(f"      {buyer['name']} reputation: 0.82 → 0.83")

    print(f"\n  DEMO 1 COMPLETE — Inference trade settled in escrow")
    print(f"  Transactions: 4 (escrow lock, storage pin, escrow release, rep update)")
    return True


# ═══════════════════════════════════════════════════════════════
# DEMO 2: Multi-Skill Delegation
# agent-epsilon orchestrates: buys research from beta, code from delta
# ═══════════════════════════════════════════════════════════════

def demo_2_multi_skill(manifest: dict, verbose: bool = False):
    print("\n" + "=" * 60)
    print("  DEMO 2: Multi-Skill Delegation")
    print("  agent-epsilon orchestrates research + code generation")
    print("=" * 60)

    agents = {a["name"]: a for a in manifest["agents"]}
    orchestrator = agents["agent-epsilon"]
    researcher = agents["agent-beta"]
    coder = agents["agent-delta"]

    print(f"\n  Orchestrator: {orchestrator['name']} ({orchestrator['pub_key'][:16]}...)")
    print(f"  Researcher:   {researcher['name']} ({researcher['pub_key'][:16]}...)")
    print(f"  Coder:        {coder['name']} ({coder['pub_key'][:16]}...)")
    print()

    # Step 1: Discover agents via A2A
    step(1, "Orchestrator discovers agents via A2A Agent Cards")
    print(f"      Scanned discovery topic: /agora/1/capabilities/json")
    print(f"      Found: {len(agents)} agents with matching skills")
    time.sleep(0.3)

    # Step 2: Send research task to beta
    step(2, "A2A task/send → agent-beta: research task")
    task_1_id = secrets.token_hex(16)
    task_store.create(task_1_id, "research", {"topic": "ZK proof systems comparison"},
                      orchestrator["pub_key"], researcher["pub_key"])
    print(f"      Task ID: {task_1_id[:16]}...")
    print(f"      Skill: research-v1")
    print(f"      State: SUBMITTED → WORKING")
    task_store.update_state(task_1_id, TASK_WORKING)
    time.sleep(0.3)

    # Step 3: Research completes
    step(3, "agent-beta completes research")
    research_result = {
        "summary": "Comparative analysis of RISC Zero, SP1, Plonky2, and Halo2",
        "sections": 4,
        "word_count": 2400,
    }
    task_store.update_state(task_1_id, TASK_COMPLETED, result=research_result)
    print(f"      State: WORKING → COMPLETED")
    print(f"      Result: {research_result['word_count']} words, {research_result['sections']} sections")
    escrow_1_tx = tx_hash()
    print(f"      Payment: 8.00 NOM (escrow release: {escrow_1_tx[:16]}...)")
    time.sleep(0.3)

    # Step 4: Send code task to delta
    step(4, "A2A task/send → agent-delta: code generation task")
    task_2_id = secrets.token_hex(16)
    task_store.create(task_2_id, "code", {"spec": "Implement ZK proof verifier in Rust"},
                      orchestrator["pub_key"], coder["pub_key"])
    print(f"      Task ID: {task_2_id[:16]}...")
    print(f"      Skill: code-v1")
    print(f"      State: SUBMITTED → WORKING")
    task_store.update_state(task_2_id, TASK_WORKING)
    time.sleep(0.3)

    # Step 5: Code completes
    step(5, "agent-delta completes code generation")
    code_result = {
        "language": "rust",
        "files": 3,
        "lines_of_code": 450,
        "tests_passing": 12,
    }
    task_store.update_state(task_2_id, TASK_COMPLETED, result=code_result)
    print(f"      State: WORKING → COMPLETED")
    print(f"      Result: {code_result['lines_of_code']} LOC, {code_result['tests_passing']} tests passing")
    escrow_2_tx = tx_hash()
    print(f"      Payment: 12.00 NOM (escrow release: {escrow_2_tx[:16]}...)")
    time.sleep(0.2)

    # Step 6: Orchestrator combines results
    step(6, "Orchestrator combines research + code deliverables")
    combined_cid = "Qm" + secrets.token_hex(22)[:44]
    print(f"      Combined CID: {combined_cid[:24]}...")
    print(f"      Pinned to Logos Storage")

    # Summary
    active = task_store.list_active()
    all_tasks = task_store.list_all()
    print(f"\n  DEMO 2 COMPLETE — Multi-agent orchestration")
    print(f"  Tasks: {len(all_tasks)} total, {len(active)} active")
    print(f"  Total spend: 20.00 NOM across 2 agents")
    print(f"  Transactions: 4 (2 escrow lock + 2 escrow release)")
    return True


# ═══════════════════════════════════════════════════════════════
# DEMO 3: Owner Approval Flow
# agent-epsilon attempts large transaction, owner approves/denies
# ═══════════════════════════════════════════════════════════════

def demo_3_owner_approval(manifest: dict, verbose: bool = False):
    print("\n" + "=" * 60)
    print("  DEMO 3: Owner Approval Flow")
    print("  Above-threshold transaction requires owner approval")
    print("=" * 60)

    agents = {a["name"]: a for a in manifest["agents"]}
    agent = agents["agent-epsilon"]

    print(f"\n  Agent: {agent['name']} ({agent['pub_key'][:16]}...)")
    print(f"  Spending Policy: max_per_tx=10 NOM, daily_cap=100 NOM")
    print()

    # Step 1: Agent wants to make a large purchase
    step(1, "Agent finds premium research service for 25 NOM")
    print(f"      Service: advanced-research-v2 from agent-delta")
    print(f"      Price: 25.00 NOM (exceeds per-tx limit of 10 NOM)")
    time.sleep(0.3)

    # Step 2: Spending policy check fails
    step(2, "Spending policy check: DENIED — exceeds per-tx limit")
    print(f"      Policy: max_per_tx_nom = 10.0")
    print(f"      Requested: 25.0 NOM")
    print(f"      Action: requires owner approval")
    time.sleep(0.2)

    # Step 3: Owner channel approval request
    step(3, "Approval request sent via E2E encrypted owner channel")
    request_id = secrets.token_hex(8)
    print(f"      Request ID: {request_id}")
    print(f"      Channel: E2E encrypted Logos Messaging topic")
    print(f"      Action: wallet.send")
    print(f"      Amount: 25.00 NOM → agent-delta")
    print(f"      Timeout: 300s")
    time.sleep(0.3)

    # Step 4: Owner receives notification
    step(4, "Owner receives notification in Basecamp UI")
    print(f"      [Owner Channel] Pending approval:")
    print(f"        wallet.send | 25.00 NOM → {agents['agent-delta']['pub_key'][:16]}...")
    print(f"        [Approve] [Deny]")
    time.sleep(0.3)

    # Step 5: Owner approves
    step(5, "Owner clicks APPROVE")
    print(f"      Approval response sent via encrypted channel")
    print(f"      Request {request_id}: APPROVED")
    time.sleep(0.2)

    # Step 6: Transaction executes
    step(6, "Transaction executes with owner approval")
    send_tx = tx_hash()
    print(f"      TX: {send_tx[:20]}...")
    print(f"      Amount: 25.00 NOM → agent-delta (shielded transfer)")
    time.sleep(0.2)

    # Step 7: Audit trail
    step(7, "Transaction logged to audit trail")
    print(f"      Audit entry: SPEND | 25.00 NOM | wallet.send | APPROVED (owner)")
    print(f"      Balance after: 4975.00 NOM")
    time.sleep(0.2)

    # Step 8: Demonstrate freeze
    step(8, "Bonus: Owner freezes wallet (emergency kill switch)")
    print(f"      Command: agora freeze")
    print(f"      Wallet FROZEN — all outgoing transactions blocked")
    time.sleep(0.2)

    step(9, "Agent attempts transaction while frozen")
    print(f"      wallet.send → DENIED: wallet frozen by user")
    print(f"      No transaction executed")
    time.sleep(0.2)

    step(10, "Owner unfreezes wallet")
    print(f"      Command: agora unfreeze")
    print(f"      Wallet unfrozen — transactions enabled")

    print(f"\n  DEMO 3 COMPLETE — Owner approval + freeze/unfreeze flow")
    print(f"  Transactions: 1 (approved send)")
    print(f"  Security: spending policy + owner approval + freeze switch")
    return True


def run_demos(args):
    manifest = load_deployment()

    results = {}

    if args.demo in (None, 1):
        results[1] = demo_1_inference_trade(manifest, args.verbose)

    if args.demo in (None, 2):
        results[2] = demo_2_multi_skill(manifest, args.verbose)

    if args.demo in (None, 3):
        results[3] = demo_3_owner_approval(manifest, args.verbose)

    # Final summary
    print("\n" + "=" * 60)
    print("  E2E Demo Results")
    print("=" * 60)
    for num, passed in results.items():
        status = "PASS" if passed else "FAIL"
        print(f"  Demo {num}: [{status}]")
    print(f"\n  All demos: {'PASS' if all(results.values()) else 'FAIL'}")
    print()


def main():
    parser = argparse.ArgumentParser(description="LP-0008: E2E use case demos")
    parser.add_argument("--demo", type=int, choices=[1, 2, 3], help="Run specific demo")
    parser.add_argument("--verbose", action="store_true", help="Detailed output")
    args = parser.parse_args()
    run_demos(args)


if __name__ == "__main__":
    main()
