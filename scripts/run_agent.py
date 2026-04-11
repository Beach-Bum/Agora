#!/usr/bin/env python3
"""
scripts/run_agent.py

Launch a reference Agora agent node.

Security: private keys are NEVER passed via CLI or environment variable.
Keys are loaded from the OS keychain or an encrypted file via AgentKeystore.

Usage:
  python scripts/run_agent.py --role seller
  python scripts/run_agent.py --role buyer --task "Summarise the cypherpunk manifesto"
  python scripts/run_agent.py --role both --name my-agent
"""

import asyncio
import argparse
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from agent.core.agent import AgoraAgent, AgentConfig
from agent.logos.messaging import CapabilityService


def make_config(agent_name: str, stake: str, role: str) -> AgentConfig:
    services = []
    if role in ("seller", "both"):
        services = [
            CapabilityService(id="inference-v1", category="inference",
                              price_per_unit="0.002", model="daemon-mamba-7b",
                              context_window=32768, avg_latency_ms=850),
            CapabilityService(id="research-v1", category="research",
                              price_per_unit="10.0", avg_latency_ms=15000),
        ]
    return AgentConfig(
        agent_name=agent_name,  # FIX-5: name only, key loaded from keychain
        stake_nom=stake,
        role=role,
        services=services,
    )


async def run_seller(config: AgentConfig):
    agent = AgoraAgent(config)
    print("[Agora] Starting seller node — press Ctrl+C to stop")
    try:
        await agent.start()
    except KeyboardInterrupt:
        await agent.stop()


async def run_buyer(config: AgentConfig, task: str):
    agent = AgoraAgent(config)

    async def buyer_flow():
        await asyncio.sleep(2)
        print(f"\n[Agora] Task: {task[:80]}…")
        result = await agent.execute_buy(
            category="inference", task=task, budget="50",
            max_price_per_unit="0.01", timeout_s=30,
        )
        if result:
            print(f"\n{'='*60}\nTASK OUTPUT:\n{'='*60}\n{result}\n{'='*60}")
        else:
            print("[Agora] Task failed — no valid delivery received")
        await agent.stop()

    await asyncio.gather(agent.start(), buyer_flow())


async def run_both(config: AgentConfig, task: str):
    agent = AgoraAgent(config)

    async def combined_flow():
        await asyncio.sleep(3)
        if task:
            result = await agent.execute_buy(
                category="inference", task=task, budget="50", timeout_s=30,
            )
            if result:
                print(f"\n[Agora] Task result:\n{result}")
        try:
            while True:
                await asyncio.sleep(10)
        except asyncio.CancelledError:
            pass

    try:
        await asyncio.gather(agent.start(), combined_flow())
    except KeyboardInterrupt:
        await agent.stop()


def main():
    parser = argparse.ArgumentParser(description="Agora reference agent")
    parser.add_argument("--role",  choices=["seller","buyer","both"], default="seller")
    parser.add_argument("--task",  default="What is the Logos stack and why does it matter?")
    parser.add_argument("--name",  default="default",
                        help="Agent name used for keychain lookup")
    parser.add_argument("--stake", default="1000",
                        help="NOM tokens to stake on registration")
    # FIX-5: --key argument intentionally REMOVED.
    # Keys are loaded from the OS keychain or ~/.agora/keys/<name>.key
    args = parser.parse_args()

    config = make_config(args.name, args.stake, args.role)

    if args.role == "seller":
        asyncio.run(run_seller(config))
    elif args.role == "buyer":
        asyncio.run(run_buyer(config, args.task))
    else:
        asyncio.run(run_both(config, args.task))


if __name__ == "__main__":
    main()
