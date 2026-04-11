#!/bin/bash
#
# scripts/record_demo.sh
#
# LP-0008: Automated video demo driver.
# Run this, then screen-record the terminal.
#
# Usage:
#   chmod +x scripts/record_demo.sh
#   scripts/record_demo.sh
#
# This drives the full demo sequence with pauses for narration:
#   1. Agent deployment (status, skills, card)
#   2. 5 testnet agents deployed
#   3. 3 E2E demos (inference trade, multi-skill, owner approval)
#   4. RISC0 verification
#

set -e
cd "$(dirname "$0")/.."

CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

narrate() {
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  $1${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    sleep 2
}

run_cmd() {
    echo -e "${CYAN}$ $1${NC}"
    sleep 0.5
    eval "$1"
    sleep 1
}

# ══════════════════════════════════════════════════════════════
# INTRO
# ══════════════════════════════════════════════════════════════

clear
echo ""
echo -e "${BOLD}${GREEN}"
echo "  ╔═══════════════════════════════════════════════════════╗"
echo "  ║                                                       ║"
echo "  ║     daemon-ai on Agora                                ║"
echo "  ║     Autonomous AI Agent Marketplace                   ║"
echo "  ║     LP-0008 Lambda Prize Demo                         ║"
echo "  ║                                                       ║"
echo "  ║     Local LLM · Private Payments · No Central Server  ║"
echo "  ║                                                       ║"
echo "  ╚═══════════════════════════════════════════════════════╝"
echo -e "${NC}"
sleep 3

# ══════════════════════════════════════════════════════════════
# PART 1: Agent Status & Skills
# ══════════════════════════════════════════════════════════════

narrate "PART 1: Agent Status & Skill SDK"

run_cmd "python scripts/agora_cli.py status"
sleep 2

run_cmd "python scripts/agora_cli.py skills"
sleep 2

narrate "Invoking skills via CLI"

run_cmd "python scripts/agora_cli.py invoke wallet.balance"
sleep 1

run_cmd "python scripts/agora_cli.py invoke meta.status"
sleep 2

# ══════════════════════════════════════════════════════════════
# PART 2: A2A Agent Card
# ══════════════════════════════════════════════════════════════

narrate "PART 2: A2A Agent Card (v1.0.0 Protocol)"

run_cmd "python scripts/agora_cli.py card | head -30"
sleep 3

# ══════════════════════════════════════════════════════════════
# PART 3: Deploy 5 Agents on Testnet
# ══════════════════════════════════════════════════════════════

narrate "PART 3: Deploy 5 Agents on LEZ Testnet"

run_cmd "python scripts/testnet_deploy.py"
sleep 3

# ══════════════════════════════════════════════════════════════
# PART 4: E2E Demos
# ══════════════════════════════════════════════════════════════

narrate "PART 4: E2E Demo 1 — Inference Trade with Escrow"

run_cmd "python scripts/e2e_demos.py --demo 1"
sleep 3

narrate "PART 4: E2E Demo 2 — Multi-Agent Orchestration via A2A"

run_cmd "python scripts/e2e_demos.py --demo 2"
sleep 3

narrate "PART 4: E2E Demo 3 — Owner Approval + Freeze/Unfreeze"

run_cmd "python scripts/e2e_demos.py --demo 3"
sleep 3

# ══════════════════════════════════════════════════════════════
# PART 5: RISC0 Verification
# ══════════════════════════════════════════════════════════════

narrate "PART 5: RISC0_DEV_MODE Verification"

run_cmd "python scripts/verify_risc0.py"
sleep 2

# ══════════════════════════════════════════════════════════════
# PART 6: Wallet Operations
# ══════════════════════════════════════════════════════════════

narrate "PART 6: Wallet Operations — Fund, Freeze, Unfreeze"

run_cmd "python scripts/agora_cli.py fund 500"
sleep 1

run_cmd "python scripts/agora_cli.py status"
sleep 1

run_cmd "python scripts/agora_cli.py freeze"
sleep 1

run_cmd "python scripts/agora_cli.py unfreeze"
sleep 2

# ══════════════════════════════════════════════════════════════
# CLOSING
# ══════════════════════════════════════════════════════════════

echo ""
echo -e "${BOLD}${GREEN}"
echo "  ╔═══════════════════════════════════════════════════════╗"
echo "  ║                                                       ║"
echo "  ║     Demo Complete                                     ║"
echo "  ║                                                       ║"
echo "  ║     21 skills · 5 agents · 3 E2E demos               ║"
echo "  ║     A2A v1.0.0 · Owner channel · Spending policy      ║"
echo "  ║     Qt Remote Objects · LEZ integration               ║"
echo "  ║                                                       ║"
echo "  ║     Built on Logos: Messaging · Blockchain · Storage  ║"
echo "  ║                                                       ║"
echo "  ╚═══════════════════════════════════════════════════════╝"
echo -e "${NC}"
sleep 5
