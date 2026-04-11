#!/usr/bin/env bash
# build_and_deploy.sh — Build Agora Logos Basecamp module and deploy to LogosApp.app
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_DIR="$SCRIPT_DIR/logos-agora-module"
UI_DIR="$SCRIPT_DIR/logos-agora-ui"
APP_FRAMEWORKS="/Applications/LogosApp.app/Contents/Frameworks"

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║      Agora — Logos Basecamp Module Build         ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ── 1. Build backend module ───────────────────────────────────────
echo "→ [1/4] Configuring logos-agora-module…"
cmake -B "$MODULE_DIR/build" -S "$MODULE_DIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH=/opt/homebrew/opt/qt@6 \
  -DLOGOS_LIBLOGOS_ROOT="$HOME/logos-core-poc/logos-liblogos" \
  -DLOGOS_CPP_SDK_ROOT="$HOME/logos-core-poc/logos-cpp-sdk"

echo ""
echo "→ [2/4] Building logos-agora-module…"
cmake --build "$MODULE_DIR/build" --target agora_module_plugin

echo ""
echo "→ [3/4] Configuring & building logos-agora-ui…"
cmake -B "$UI_DIR/build" -S "$UI_DIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH=/opt/homebrew/opt/qt@6 \
  -DLOGOS_LIBLOGOS_ROOT="$HOME/logos-core-poc/logos-liblogos" \
  -DLOGOS_CPP_SDK_ROOT="$HOME/logos-core-poc/logos-cpp-sdk" \
  -DLOGOS_APP_INTERFACES="$HOME/logos-core-poc/logos-app-poc/interfaces"

cmake --build "$UI_DIR/build" --target agora_ui

echo ""
echo "→ [4/4] Deploying to LogosApp.app…"
cp "$MODULE_DIR/build/agora_module_plugin.dylib" "$APP_FRAMEWORKS/"
cp "$UI_DIR/build/agora_ui.dylib"               "$APP_FRAMEWORKS/"

echo ""
echo "✓ Deployed:"
echo "  $APP_FRAMEWORKS/agora_module_plugin.dylib"
echo "  $APP_FRAMEWORKS/agora_ui.dylib"
echo ""
echo "Launch LogosApp — Agora will appear as a module tile."
echo ""
echo "Optional: start daemon-ai runtime for local LLM inference:"
echo "  cd ~/daemon-ai/daemon/build && ./daemon --port 8765"
