#!/usr/bin/env bash
# LP-0008 Full Demo — Real Blockchain + Agent Skills
# Records everything in sequence for the narrated video
set -e

G="\033[32m"
Y="\033[33m"
C="\033[36m"
R="\033[31m"
W="\033[0m"
B="\033[1m"

pause() { sleep "${1:-2}"; }

banner() {
    echo ""
    echo -e "${G}════════════════════════════════════════════════════════════════${W}"
    echo -e "${G}  $1${W}"
    echo -e "${G}════════════════════════════════════════════════════════════════${W}"
    echo ""
    pause 3
}

# ── INTRO ────────────────────────────────────────────────────
clear
banner "LP-0008: daemon-ai on Agora — Lambda Prize Demo"
echo -e "  ${C}Autonomous AI Agent Module for the Logos Stack${W}"
echo -e "  ${Y}Real blockchain · Real ZK proofs · Real transfers${W}"
echo ""
pause 3

# ── PART 1: REAL BLOCKCHAIN ─────────────────────────────────
banner "Part 1: Real Blockchain Node"
echo -e "  Running against ${B}logos-blockchain-node${W} (standalone)"
echo -e "  Groth16 ZK circuits — not mocked"
echo ""
pause 2

python3 scripts/demo_real_node.py
pause 3

# ── PART 2: AGENT STATUS + SKILLS ───────────────────────────
banner "Part 2: Agent Status + 21 Skills"

echo -e "  ${C}\$ python scripts/agora_cli.py status${W}"
python3 scripts/agora_cli.py status
pause 2

echo ""
echo -e "  ${C}\$ python scripts/agora_cli.py skills${W}"
python3 scripts/agora_cli.py skills
pause 2

echo ""
echo -e "  ${C}\$ python scripts/agora_cli.py invoke wallet.balance${W}"
python3 scripts/agora_cli.py invoke wallet.balance
pause 2

echo ""
echo -e "  ${C}\$ python scripts/agora_cli.py invoke meta.status${W}"
python3 scripts/agora_cli.py invoke meta.status
pause 2

# ── PART 3: A2A AGENT CARD ──────────────────────────────────
banner "Part 3: A2A v1.0.0 Agent Card"
echo -e "  ${C}\$ python scripts/agora_cli.py card${W}"
python3 scripts/agora_cli.py card | head -30
echo "  ..."
pause 3

# ── PART 4: DEPLOY 5 AGENTS ─────────────────────────────────
banner "Part 4: Deploy 5 Agents on Testnet"
echo -e "  ${C}\$ python scripts/testnet_deploy.py${W}"
python3 scripts/testnet_deploy.py
pause 3

# ── PART 5: E2E DEMOS ───────────────────────────────────────
banner "Part 5: 3 End-to-End Demos"
echo -e "  ${C}\$ python scripts/e2e_demos.py${W}"
python3 scripts/e2e_demos.py
pause 3

# ── PART 6: ZK VERIFICATION ─────────────────────────────────
banner "Part 6: ZK Proof Verification"
echo -e "  ${Y}Note: RISC0 was removed from logos-blockchain in Sept 2025${W}"
echo -e "  ${Y}Now uses Groth16 circuits — real proofs demonstrated in Part 1${W}"
echo ""
python3 scripts/verify_risc0.py
pause 3

# ── PART 7: WALLET OPS ──────────────────────────────────────
banner "Part 7: Wallet Operations"

echo -e "  ${C}\$ python scripts/agora_cli.py fund 500${W}"
python3 scripts/agora_cli.py fund 500
pause 1

echo ""
echo -e "  ${C}\$ python scripts/agora_cli.py freeze${W}"
python3 scripts/agora_cli.py freeze
pause 1

echo ""
echo -e "  ${C}\$ python scripts/agora_cli.py unfreeze${W}"
python3 scripts/agora_cli.py unfreeze
pause 2

# ── CLOSING ──────────────────────────────────────────────────
banner "Demo Complete"
echo -e "  ${G}✓${W} Real blockchain node with Groth16 ZK proofs"
echo -e "  ${G}✓${W} 21 composable skills across 5 categories"
echo -e "  ${G}✓${W} A2A v1.0.0 Agent Cards + task lifecycle"
echo -e "  ${G}✓${W} 5 agents deployed with unique identities"
echo -e "  ${G}✓${W} 3 E2E demos: inference trade, multi-skill, owner approval"
echo -e "  ${G}✓${W} E2E encrypted owner channel with spending policy"
echo -e "  ${G}✓${W} Wallet operations: fund, freeze, unfreeze"
echo ""
echo -e "  ${C}github.com/Beach-Bum/Agora${W}"
echo ""
pause 5
