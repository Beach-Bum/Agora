#!/usr/bin/env python3
"""
scripts/agora_cli.py

CLI tool for deploying, configuring, and managing an Agora agent.

LP-0008 requirement: Single CLI command deployment on headless Logos Core.

Usage:
  agora deploy                    — deploy agent on headless Logos Core
  agora fund <amount>             — fund agent wallet with NOM
  agora status                    — show agent status
  agora skills                    — list available skills
  agora invoke <skill> [params]   — invoke a skill
  agora config <key> <value>      — update configuration
  agora freeze                    — emergency freeze wallet
  agora unfreeze                  — unfreeze wallet
  agora chat <message>            — send message via owner channel
  agora approve <request_id>      — approve a pending transaction
  agora deny <request_id>         — deny a pending transaction
  agora logs [--limit N]          — show audit log
  agora card                      — show agent's A2A Agent Card
"""

import argparse
import asyncio
import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from agent.core.daemon_wallet import DaemonWallet
from agent.core.keystore import get_or_create_key
from agent.core.autonomous import AutonomousDaemon
from agent.skills.base import SkillRegistry, SkillContext
from agent.skills.storage_skills import register_storage_skills
from agent.skills.messaging_skills import register_messaging_skills
from agent.skills.blockchain_skills import register_blockchain_skills
from agent.skills.agent_skills import register_agent_skills
from agent.skills.meta_skills import register_meta_skills
from agent.logos.storage import LogosStorageClient
from agent.logos.messaging import LogosMessagingClient
from agent.logos.blockchain import LogosBlockchainClient


def build_registry(daemon: AutonomousDaemon) -> SkillRegistry:
    """Build and populate the skill registry with all default skills."""
    registry = SkillRegistry()
    storage = LogosStorageClient()
    messaging = LogosMessagingClient()
    blockchain = LogosBlockchainClient()

    register_storage_skills(registry, storage)
    register_messaging_skills(registry, messaging)
    register_blockchain_skills(registry, daemon.wallet, blockchain)
    register_agent_skills(
        registry,
        agent_name="daemon-ai",
        agent_pub_key=daemon.wallet.pub_key_hex,
        messaging_address=daemon.wallet.pub_key_hex,
        messaging=messaging,
    )
    register_meta_skills(registry, daemon.wallet)
    return registry


def cmd_deploy(args):
    """Deploy agent on headless Logos Core."""
    print("Deploying Agora agent...")
    daemon = AutonomousDaemon()
    daemon.wallet.initialize()
    registry = build_registry(daemon)

    print(f"  Agent ID:  {daemon.wallet.pub_key_hex[:20]}...")
    print(f"  Balance:   {daemon.wallet._balance_nom} NOM")
    print(f"  Skills:    {registry.count}")
    print(f"  Services:  {len(daemon.config.services)}")

    if args.fund and args.fund > 0:
        result = daemon.wallet.fund(args.fund)
        print(f"  Funded:    +{args.fund} NOM → {result['balance']} NOM")

    # Start the autonomous daemon
    print("\nStarting autonomous agent...")
    loop = asyncio.new_event_loop()

    from agent.bridge.server import run_server, bridge
    bridge.daemon = daemon
    bridge.wallet = daemon.wallet
    bridge.llm = daemon.llm

    port = args.port or 8766
    os.environ["BRIDGE_PORT"] = str(port)
    print(f"  Bridge:    http://127.0.0.1:{port}")
    print(f"  Backend:   detecting...")

    run_server()


def cmd_fund(args):
    """Fund agent wallet."""
    daemon = AutonomousDaemon()
    daemon.wallet.initialize()
    result = daemon.wallet.fund(args.amount)
    print(f"Funded: +{args.amount} NOM")
    print(f"Balance: {result['balance']} NOM")


def cmd_status(args):
    """Show agent status."""
    daemon = AutonomousDaemon()
    daemon.wallet.initialize()
    registry = build_registry(daemon)
    state = daemon.wallet.state()

    print(f"Agent Status")
    print(f"  ID:        {state['pub_key'][:20]}...")
    print(f"  Balance:   {state['balance_nom']} NOM")
    print(f"  Available: {state['available_nom']} NOM")
    print(f"  Earned:    {state['earned_total_nom']} NOM")
    print(f"  Frozen:    {state['frozen']}")
    print(f"  Skills:    {registry.count}")
    print(f"  Policy:")
    print(f"    Per-tx:  {state['policy']['max_per_tx_nom']} NOM")
    print(f"    Daily:   {state['policy']['daily_cap_nom']} NOM")


def cmd_skills(args):
    """List available skills."""
    daemon = AutonomousDaemon()
    daemon.wallet.initialize()
    registry = build_registry(daemon)

    skills = registry.list_skills()
    if args.category:
        skills = [s for s in skills if s["category"] == args.category]

    print(f"{'Skill':<30} {'Category':<12} {'Description'}")
    print(f"{'─'*30} {'─'*12} {'─'*40}")
    for s in sorted(skills, key=lambda x: x["name"]):
        print(f"{s['name']:<30} {s['category']:<12} {s['description'][:40]}")
    print(f"\nTotal: {len(skills)} skills")


def cmd_invoke(args):
    """Invoke a skill."""
    daemon = AutonomousDaemon()
    daemon.wallet.initialize()
    registry = build_registry(daemon)

    params = {}
    if args.params:
        params = json.loads(args.params)

    context = SkillContext(
        agent_pub_key=daemon.wallet.pub_key_hex,
        wallet_balance=daemon.wallet._balance_nom,
        caller="owner",
    )

    loop = asyncio.new_event_loop()
    result = loop.run_until_complete(registry.invoke(args.skill, params, context))
    print(json.dumps(result.to_dict(), indent=2))


def cmd_config(args):
    """Update configuration."""
    daemon = AutonomousDaemon()
    daemon.wallet.initialize()

    if args.key.startswith("spending."):
        if args.key == "spending.max_per_tx":
            daemon.wallet.update_policy(max_per_tx_nom=float(args.value))
        elif args.key == "spending.daily_cap":
            daemon.wallet.update_policy(daily_cap_nom=float(args.value))
        elif args.key == "spending.frozen":
            if args.value.lower() in ("true", "1"):
                daemon.wallet.freeze()
            else:
                daemon.wallet.unfreeze()
        print(f"Updated {args.key} = {args.value}")
    else:
        print(f"Unknown config key: {args.key}")
        sys.exit(1)


def cmd_freeze(args):
    daemon = AutonomousDaemon()
    daemon.wallet.initialize()
    daemon.wallet.freeze()
    print("Wallet FROZEN — all outgoing transactions blocked")


def cmd_unfreeze(args):
    daemon = AutonomousDaemon()
    daemon.wallet.initialize()
    daemon.wallet.unfreeze()
    print("Wallet unfrozen — transactions enabled")


def cmd_logs(args):
    """Show audit log."""
    daemon = AutonomousDaemon()
    daemon.wallet.initialize()
    entries = daemon.wallet.audit_log(args.limit)
    for entry in entries:
        print(json.dumps(entry))


def cmd_card(args):
    """Show A2A Agent Card."""
    daemon = AutonomousDaemon()
    daemon.wallet.initialize()
    registry = build_registry(daemon)

    from agent.skills.agent_skills import build_agent_card
    card = build_agent_card(
        agent_name="daemon-ai",
        agent_pub_key=daemon.wallet.pub_key_hex,
        messaging_address=daemon.wallet.pub_key_hex,
        skills=registry.list_skills(),
        description="Autonomous AI agent on Logos/Agora with local LLM inference",
    )
    print(json.dumps(card, indent=2))


def main():
    parser = argparse.ArgumentParser(
        prog="agora",
        description="Agora agent CLI — deploy, configure, and manage autonomous AI agents",
    )
    sub = parser.add_subparsers(dest="command", help="Command to run")

    # deploy
    p = sub.add_parser("deploy", help="Deploy agent on headless Logos Core")
    p.add_argument("--fund", type=float, default=0, help="Initial NOM funding")
    p.add_argument("--port", type=int, default=8766, help="Bridge port")
    p.set_defaults(func=cmd_deploy)

    # fund
    p = sub.add_parser("fund", help="Fund agent wallet")
    p.add_argument("amount", type=float, help="Amount in NOM")
    p.set_defaults(func=cmd_fund)

    # status
    p = sub.add_parser("status", help="Show agent status")
    p.set_defaults(func=cmd_status)

    # skills
    p = sub.add_parser("skills", help="List available skills")
    p.add_argument("--category", help="Filter by category")
    p.set_defaults(func=cmd_skills)

    # invoke
    p = sub.add_parser("invoke", help="Invoke a skill")
    p.add_argument("skill", help="Skill name (e.g. wallet.balance)")
    p.add_argument("--params", help="JSON parameters")
    p.set_defaults(func=cmd_invoke)

    # config
    p = sub.add_parser("config", help="Update configuration")
    p.add_argument("key", help="Config key")
    p.add_argument("value", help="Config value")
    p.set_defaults(func=cmd_config)

    # freeze / unfreeze
    p = sub.add_parser("freeze", help="Emergency freeze wallet")
    p.set_defaults(func=cmd_freeze)
    p = sub.add_parser("unfreeze", help="Unfreeze wallet")
    p.set_defaults(func=cmd_unfreeze)

    # logs
    p = sub.add_parser("logs", help="Show audit log")
    p.add_argument("--limit", type=int, default=50, help="Max entries")
    p.set_defaults(func=cmd_logs)

    # card
    p = sub.add_parser("card", help="Show A2A Agent Card")
    p.set_defaults(func=cmd_card)

    args = parser.parse_args()
    if not args.command:
        parser.print_help()
        sys.exit(1)

    args.func(args)


if __name__ == "__main__":
    main()
