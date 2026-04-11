#!/usr/bin/env bash
# scripts/setup.sh — Install Agora dependencies
set -e

echo "╔══════════════════════════════════════════╗"
echo "║     Agora — Setup                    ║"
echo "╚══════════════════════════════════════════╝"

# Python deps
echo ""
echo "→ Installing Python dependencies…"
pip install -r requirements.txt

# Logos Storage node (Docker)
echo ""
echo "→ Checking Docker for Logos Storage node…"
if command -v docker &>/dev/null; then
  if ! docker ps | grep -q nim-codex; then
    echo "  Starting Logos Storage node…"
    docker run -d -p 8080:8080 --name nim-codex codexstorage/nim-codex 2>/dev/null || \
    echo "  ⚠ Could not start Logos Storage — run manually: docker run -p 8080:8080 codexstorage/nim-codex"
  else
    echo "  ✓ Logos Storage node already running"
  fi
else
  echo "  ⚠ Docker not found — install Docker to run Logos Storage node"
fi

# daemon-ai check
echo ""
echo "→ Checking daemon-ai runtime…"
if [ -d "$HOME/daemon-ai/daemon" ]; then
  echo "  ✓ Found daemon-ai at ~/daemon-ai/daemon"
else
  echo "  ⚠ daemon-ai not found — clone from https://github.com/daemon-ai/daemon"
  echo "    git clone https://github.com/daemon-ai/daemon ~/daemon-ai/daemon"
  echo "    (Agora will fall back to Ollama or mock mode)"
fi

echo ""
echo "→ Checking Ollama (fallback LLM)…"
if command -v ollama &>/dev/null; then
  echo "  ✓ Ollama found"
else
  echo "  ⚠ Ollama not found — install from https://ollama.com for fallback LLM"
fi

echo ""
echo "✓ Setup complete!"
echo ""
echo "Run an agent node:"
echo "  python scripts/run_agent.py --role seller     # Sell inference"
echo "  python scripts/run_agent.py --role buyer      # Buy a task"
echo "  python scripts/run_agent.py --role both       # Do both"
