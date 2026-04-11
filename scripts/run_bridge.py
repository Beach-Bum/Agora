#!/usr/bin/env python3
"""
scripts/run_bridge.py

Launch the daemon-ai bridge server for Basecamp integration.

The bridge connects the QML plugin UI to:
  - daemon-ai LLM runtime (localhost:8765)
  - Autonomous agent wallet + Agora marketplace
  - Logos stack (Messaging, Blockchain, Storage)

Usage:
  python scripts/run_bridge.py
  python scripts/run_bridge.py --port 8766
  python scripts/run_bridge.py --fund 1000    # Pre-fund daemon wallet with 1000 NOM

Environment variables:
  DAEMON_AI_URL   — daemon-ai endpoint (default: http://localhost:8765)
  OLLAMA_URL      — Ollama fallback (default: http://localhost:11434)
  BRIDGE_HOST     — bind address (default: 127.0.0.1)
  BRIDGE_PORT     — bind port (default: 8766)
"""

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from agent.bridge.server import run_server, bridge


def main():
    parser = argparse.ArgumentParser(description="daemon-ai bridge server")
    parser.add_argument("--port", type=int, default=8766, help="Bridge port (default: 8766)")
    parser.add_argument("--host", default="127.0.0.1", help="Bind address (default: 127.0.0.1)")
    parser.add_argument("--fund", type=float, default=0, help="Pre-fund daemon wallet with NOM")
    args = parser.parse_args()

    os.environ["BRIDGE_HOST"] = args.host
    os.environ["BRIDGE_PORT"] = str(args.port)

    # Pre-fund wallet if requested
    if args.fund > 0:
        bridge.wallet.initialize()
        result = bridge.wallet.fund(args.fund)
        print(f"[Bridge] Pre-funded wallet: {result['balance']} NOM")

    run_server()


if __name__ == "__main__":
    main()
