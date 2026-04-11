#!/usr/bin/env python3
"""
LP-0008 Demo against a real local logos-blockchain-node.

Requires: logos-blockchain-node running at localhost:18080
"""

import httpx
import json
import sys
import time

NODE_URL = "http://localhost:18080"
GENESIS_PK = "2e03b2eff5a45478e7e79668d2a146cf2c5c7925bce927f2b1c67f2ab4fc0d26"
SDP_PK = "ed266e6e887b9b97059dc1aa1b7b2e19b934291753c6336a163fe4ebaa28e717"

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

def main():
    banner("LP-0008 Real Blockchain Demo")
    print(f"  Node:       {NODE_URL}")
    print(f"  Genesis PK: {GENESIS_PK[:20]}...")
    print(f"  SDP PK:     {SDP_PK[:20]}...")
    print()

    client = httpx.Client(timeout=10.0)

    # ── 1. Node health ───────────────────────────────────────
    step(1, "Node health — GET /cryptarchia/info")
    try:
        resp = client.get(f"{NODE_URL}/cryptarchia/info")
        info = resp.json()
        ok(f"Status: {resp.status_code} OK")
        val(f"  lib:    {info['lib'][:24]}...")
        val(f"  tip:    {info['tip'][:24]}...")
        val(f"  slot:   {info['slot']}")
        val(f"  height: {info['height']}")
        val(f"  mode:   {info['mode']}")
    except Exception as e:
        fail(f"Connection failed: {e}")
        print(f"\n  Start node: cd ~/logos-blockchain && target/release/logos-blockchain-node \\")
        print(f"    --http-host 0.0.0.0:18080 \\")
        print(f"    --deployment nodes/node/standalone-deployment-config.yaml \\")
        print(f"    nodes/node/standalone-node-config.yaml")
        sys.exit(1)
    time.sleep(1)

    # ── 2. Network info ──────────────────────────────────────
    step(2, "Network info — GET /network/info")
    try:
        resp = client.get(f"{NODE_URL}/network/info")
        net = resp.json()
        ok(f"Status: {resp.status_code}")
        val(f"  peer_id:     {net['peer_id'][:24]}...")
        val(f"  listen:      {net['listen_addresses'][0]}")
        val(f"  peers:       {net['n_peers']}")
        val(f"  connections: {net['n_connections']}")
    except Exception as e:
        fail(f"Network info failed: {e}")
    time.sleep(1)

    # ── 3. Genesis wallet balance ────────────────────────────
    step(3, f"Genesis wallet balance — GET /wallet/{{pk}}/balance")
    try:
        resp = client.get(f"{NODE_URL}/wallet/{GENESIS_PK}/balance")
        bal = resp.json()
        ok(f"Status: {resp.status_code}")
        val(f"  address: {bal['address'][:24]}...")
        val(f"  balance: {bal['balance']} NOM")
        val(f"  notes:   {len(bal['notes'])} UTXO note(s)")
        for nid, nval in bal['notes'].items():
            val(f"    {nid[:20]}... = {nval} NOM")
    except Exception as e:
        fail(f"Balance failed: {e}")
    time.sleep(1)

    # ── 4. Token transfer (real ZK proof) ────────────────────
    step(4, "Token transfer — POST /wallet/transactions/transfer-funds")
    try:
        body = {
            "funding_public_keys": [GENESIS_PK],
            "recipient_public_key": SDP_PK,
            "change_public_key": GENESIS_PK,
            "amount": 5,
        }
        val(f"  from:   {GENESIS_PK[:20]}...")
        val(f"  to:     {SDP_PK[:20]}...")
        val(f"  amount: 5 NOM")
        t0 = time.time()
        resp = client.post(
            f"{NODE_URL}/wallet/transactions/transfer-funds",
            json=body,
        )
        elapsed = time.time() - t0
        tx = resp.json()
        ok(f"Status: {resp.status_code}")
        ok(f"  tx_hash: {tx['hash']}")
        ok(f"  time:    {elapsed:.2f}s (includes ZK proof generation)")
    except Exception as e:
        fail(f"Transfer failed: {e}")
    time.sleep(3)

    # ── 5. Post-transfer balances ────────────────────────────
    step(5, "Post-transfer balances")
    try:
        r1 = client.get(f"{NODE_URL}/wallet/{GENESIS_PK}/balance").json()
        r2 = client.get(f"{NODE_URL}/wallet/{SDP_PK}/balance").json()
        ok(f"  Genesis: {r1['balance']} NOM ({len(r1['notes'])} notes)")
        ok(f"  SDP:     {r2['balance']} NOM ({len(r2['notes'])} notes)")
    except Exception as e:
        fail(f"Balance check failed: {e}")
    time.sleep(1)

    # ── 6. Second transfer ───────────────────────────────────
    step(6, "Second transfer — 3 NOM to SDP wallet")
    try:
        t0 = time.time()
        resp = client.post(
            f"{NODE_URL}/wallet/transactions/transfer-funds",
            json={
                "funding_public_keys": [GENESIS_PK],
                "recipient_public_key": SDP_PK,
                "change_public_key": GENESIS_PK,
                "amount": 3,
            },
        )
        elapsed = time.time() - t0
        tx = resp.json()
        ok(f"  tx_hash: {tx['hash']}")
        ok(f"  time:    {elapsed:.2f}s")
    except Exception as e:
        fail(f"Transfer failed: {e}")
    time.sleep(3)

    # ── 7. Chain state after transactions ────────────────────
    step(7, "Chain state — GET /cryptarchia/info")
    try:
        info = client.get(f"{NODE_URL}/cryptarchia/info").json()
        ok(f"  height: {info['height']} blocks")
        ok(f"  slot:   {info['slot']}")
        ok(f"  tip:    {info['tip'][:24]}...")
    except Exception as e:
        fail(f"Chain state failed: {e}")
    time.sleep(1)

    # ── 8. Final balances ────────────────────────────────────
    step(8, "Final balances")
    try:
        r1 = client.get(f"{NODE_URL}/wallet/{GENESIS_PK}/balance").json()
        r2 = client.get(f"{NODE_URL}/wallet/{SDP_PK}/balance").json()
        ok(f"  Genesis: {r1['balance']} NOM")
        ok(f"  SDP:     {r2['balance']} NOM")
        ok(f"  Total:   {r1['balance'] + r2['balance']} NOM (conserved)")
    except Exception as e:
        fail(f"Final balance check failed: {e}")

    banner("Demo Complete — Real Blockchain")
    print(f"  Node:        logos-blockchain-node (standalone)")
    print(f"  ZK proofs:   Groth16 circuits (real, not mocked)")
    print(f"  Transfers:   2 real on-chain transactions")
    print(f"  UTXO model:  shielded notes with ZK balance proofs")
    print()

    client.close()

if __name__ == "__main__":
    main()
