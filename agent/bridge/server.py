"""
agent/bridge/server.py

HTTP bridge between the daemon-ai QML plugin (Basecamp) and the Python agent backend.

Architecture:
    QML Plugin (XMLHttpRequest)  -->  Bridge (localhost:8766)  -->  daemon-ai (localhost:8765)
                                                               -->  Autonomous Agent (Logos stack)
                                                               -->  DaemonWallet (own keys, own NOM)

Endpoints:
    GET  /health              — bridge + daemon-ai status
    POST /chat                — send message, get daemon-ai response
    GET  /status              — daemon stats (model, backend, tokens)
    POST /model               — switch active model

    GET  /wallet              — wallet balance, policy, escrows
    POST /wallet/fund         — fund daemon's wallet with NOM
    POST /wallet/freeze       — emergency freeze
    POST /wallet/unfreeze     — unfreeze
    POST /wallet/policy       — update spending policy

    GET  /agent               — full autonomous agent state
    GET  /agent/events        — event log since cursor
    POST /agent/buy           — trigger a buy on Agora
    POST /agora/intent        — evaluate an incoming buy intent
    GET  /agent/audit         — wallet audit trail
    GET  /agent/card          — A2A Agent Card

    GET  /skills              — list available skills
    POST /skills/invoke       — invoke a skill by name

    POST /owner/chat          — send chat message via owner channel
    POST /owner/approve       — approve a pending transaction
    POST /owner/deny          — deny a pending transaction
    GET  /owner/pending       — list pending approval requests
"""

import asyncio
import json
import time
import os
import sys
import secrets
from http.server import HTTPServer, BaseHTTPRequestHandler
from threading import Thread
from typing import Optional

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

from agent.daemon.llm import DaemonLLM, AgentReasoner, LLMResponse
from agent.core.daemon_wallet import DaemonWallet
from agent.core.autonomous import AutonomousDaemon, DaemonConfig

BRIDGE_HOST = os.environ.get("BRIDGE_HOST", "127.0.0.1")
BRIDGE_PORT = int(os.environ.get("BRIDGE_PORT", "8766"))

# Auth token — written to file on startup, QML plugin reads it
AUTH_TOKEN_FILE = os.path.expanduser("~/.agora/bridge_token")
MAX_REQUEST_BYTES = 16384  # 16KB request body limit


class DaemonBridge:
    """Stateful bridge wrapping AutonomousDaemon, DaemonWallet, and DaemonLLM."""

    def __init__(self):
        self.daemon = AutonomousDaemon()
        self.llm = self.daemon.llm
        self.wallet = self.daemon.wallet
        self.backend: Optional[str] = None
        self.current_model = "mamba-370m"
        self.total_tokens = 0
        self.total_requests = 0
        self.start_time = time.time()
        self.chat_history: list[dict] = []
        self._loop: Optional[asyncio.AbstractEventLoop] = None
        self._auth_token: str = ""
        self._daemon_thread: Optional[Thread] = None

    def _get_loop(self) -> asyncio.AbstractEventLoop:
        if self._loop is None or self._loop.is_closed():
            self._loop = asyncio.new_event_loop()
        return self._loop

    def generate_auth_token(self) -> str:
        """Generate auth token and write to file (mode 0600)."""
        self._auth_token = secrets.token_hex(32)
        os.makedirs(os.path.dirname(AUTH_TOKEN_FILE), exist_ok=True)
        with open(AUTH_TOKEN_FILE, "w") as f:
            f.write(self._auth_token)
        os.chmod(AUTH_TOKEN_FILE, 0o600)
        return self._auth_token

    def check_auth(self, token: str) -> bool:
        if not self._auth_token:
            return True  # No auth configured
        return token == self._auth_token

    def initialize(self):
        """Initialize wallet and detect LLM backend."""
        self.wallet.initialize()
        self.detect_backend()
        print(f"[Bridge] Wallet: {self.wallet.pub_key_hex[:20]}...")
        print(f"[Bridge] Balance: {self.wallet._balance_nom} NOM")

    def start_daemon_background(self):
        """Start the autonomous agent in a background thread."""
        def _run():
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            try:
                loop.run_until_complete(self.daemon.start())
            except Exception as e:
                print(f"[Bridge] Daemon error: {e}")

        self._daemon_thread = Thread(target=_run, daemon=True)
        self._daemon_thread.start()
        print("[Bridge] Autonomous daemon started in background")

    def detect_backend(self) -> str:
        loop = self._get_loop()
        loop.run_until_complete(self.llm._ensure_backend())
        self.backend = self.llm._backend
        return self.backend or "mock"

    # ── Health / Status ──────────────────────────────────────────

    def health(self) -> dict:
        uptime = int(time.time() - self.start_time)
        return {
            "status": "ok",
            "backend": self.backend or "mock",
            "model": self.current_model,
            "uptime_s": uptime,
            "total_tokens": self.total_tokens,
            "total_requests": self.total_requests,
            "wallet_balance": self.wallet._balance_nom,
            "wallet_frozen": self.wallet.policy.frozen,
            "daemon_running": self.daemon._running,
        }

    def status(self) -> dict:
        return {
            "connected": self.backend in ("daemon", "ollama", "openai"),
            "backend": self.backend or "mock",
            "model": self.current_model,
            "total_tokens": self.total_tokens,
            "total_requests": self.total_requests,
            "uptime_s": int(time.time() - self.start_time),
            "available_models": [
                {"name": "mamba-370m", "params": "370M", "size": "740 MB", "speed": "~45 tok/s"},
                {"name": "mamba-1.4b", "params": "1.4B", "size": "2.8 GB", "speed": "~18 tok/s"},
                {"name": "mamba-2.8b", "params": "2.8B", "size": "5.6 GB", "speed": "~9 tok/s"},
            ],
        }

    # ── Chat ─────────────────────────────────────────────────────

    def chat(self, message: str) -> dict:
        if len(message) > 4000:
            return {"role": "system", "content": "Message too long (max 4000 chars)", "error": True}

        self.chat_history.append({"role": "user", "content": message, "ts": time.time()})

        system = (
            "You are daemon-ai, a sovereign local AI agent running the Mamba SSM architecture. "
            "You run entirely on the user's hardware with no external API calls. "
            "You are part of the Agora decentralized AI marketplace on the Logos stack. "
            "You have your own wallet and can autonomously buy and sell AI services. "
            "Be concise and technical. Reference your Mamba SSM architecture when relevant."
        )

        recent = self.chat_history[-10:]
        context_parts = []
        for msg in recent[:-1]:
            prefix = "User" if msg["role"] == "user" else "daemon-ai"
            context_parts.append(f"{prefix}: {msg['content']}")

        prompt = ""
        if context_parts:
            prompt = "Previous conversation:\n" + "\n".join(context_parts) + "\n\n"
        prompt += f"User: {message}\ndaemon-ai:"

        loop = self._get_loop()
        try:
            # Pass model=None so the LLM layer picks the right model for its backend
            # (e.g. llama3.2 for Ollama, mamba-370m for daemon-ai native)
            model = self.current_model if self.backend == "daemon" else None
            resp: LLMResponse = loop.run_until_complete(
                self.llm.complete(
                    prompt=prompt, system=system,
                    max_tokens=512, temperature=0.7,
                    model=model, trusted=True,
                )
            )

            self.total_tokens += resp.input_tokens + resp.output_tokens
            self.total_requests += 1

            reply = _sanitize_llm_output(resp.text.strip())
            self.chat_history.append({"role": "daemon", "content": reply, "ts": time.time()})

            return {
                "role": "daemon",
                "content": reply,
                "model": resp.model,
                "backend": resp.backend,
                "input_tokens": resp.input_tokens,
                "output_tokens": resp.output_tokens,
                "latency_ms": round(resp.latency_ms, 1),
                "total_tokens": self.total_tokens,
            }
        except Exception as e:
            error_msg = f"Inference error: {e}"
            self.chat_history.append({"role": "system", "content": error_msg, "ts": time.time()})
            return {"role": "system", "content": error_msg, "error": True}

    def switch_model(self, model_name: str) -> dict:
        valid = ["mamba-370m", "mamba-1.4b", "mamba-2.8b"]
        if model_name not in valid:
            return {"error": f"Unknown model: {model_name}", "valid": valid}
        self.current_model = model_name
        return {"model": self.current_model, "message": f"Switched to {model_name}"}

    # ── Wallet ───────────────────────────────────────────────────

    def wallet_state(self) -> dict:
        return self.wallet.state()

    def wallet_fund(self, amount: float) -> dict:
        if amount <= 0 or amount > 100000:
            return {"error": "Invalid amount (0 < amount <= 100000)"}
        return self.wallet.fund(amount)

    def wallet_freeze(self) -> dict:
        return self.wallet.freeze()

    def wallet_unfreeze(self) -> dict:
        return self.wallet.unfreeze()

    def wallet_update_policy(self, updates: dict) -> dict:
        return self.wallet.update_policy(**updates)

    # ── Agent ────────────────────────────────────────────────────

    def agent_state(self) -> dict:
        return self.daemon.state()

    def agent_events(self, since: int = 0) -> dict:
        return self.daemon.get_events(since)

    def agent_buy(self, category: str, task: str, budget: float) -> dict:
        loop = self._get_loop()
        return loop.run_until_complete(
            self.daemon.buy(category, task, budget)
        )

    def agent_audit(self, limit: int = 50) -> list:
        return self.wallet.audit_log(limit)

    # ── Skills ──────────────────────────────────────────────────

    def list_skills(self, category: str = None) -> dict:
        if not self.daemon.registry:
            self.daemon.build_registry()
        if category:
            skills = self.daemon.registry.list_by_category(category)
        else:
            skills = self.daemon.registry.list_skills()
        return {"skills": skills, "count": len(skills)}

    def invoke_skill(self, name: str, params: dict) -> dict:
        loop = self._get_loop()
        return loop.run_until_complete(
            self.daemon.invoke_skill(name, params)
        )

    def agent_card(self) -> dict:
        loop = self._get_loop()
        return loop.run_until_complete(
            self.daemon.invoke_skill("agent.card", {})
        )

    # ── Owner Channel ───────────────────────────────────────────

    def owner_chat(self, message: str) -> dict:
        if not self.daemon.owner_channel:
            return {"error": "Owner channel not initialized"}
        loop = self._get_loop()
        try:
            loop.run_until_complete(self.daemon.owner_channel.send_chat(message))
            return {"sent": True, "message": message}
        except Exception as e:
            return {"error": str(e)}

    def owner_approve(self, request_id: str) -> dict:
        if not self.daemon.owner_channel:
            return {"error": "Owner channel not initialized"}
        self.daemon.owner_channel.handle_approval_response(request_id, True)
        return {"approved": True, "request_id": request_id}

    def owner_deny(self, request_id: str) -> dict:
        if not self.daemon.owner_channel:
            return {"error": "Owner channel not initialized"}
        self.daemon.owner_channel.handle_approval_response(request_id, False)
        return {"denied": True, "request_id": request_id}

    def owner_pending(self) -> dict:
        if not self.daemon.owner_channel:
            return {"pending": []}
        return {"pending": self.daemon.owner_channel.pending_approvals()}

    # ── Agora Intent Evaluation ──────────────────────────────────

    def agora_evaluate_intent(self, intent: dict) -> dict:
        """Evaluate an incoming buy intent through the autonomous daemon."""
        loop = self._get_loop()

        # Log to daemon's event stream
        self.daemon._emit("intent_manual",
                         msg="Manual intent evaluation triggered from UI",
                         intent=intent)

        try:
            decision = loop.run_until_complete(
                self.daemon.reasoner.evaluate_intent(intent)
            )

            action = decision.get("action", "reject")
            reason = decision.get("reason", "")

            if action == "accept":
                # Record simulated earning
                budget = float(intent.get("budget", "0"))
                est_price = min(budget, 4.80)
                self.wallet.earn(est_price, intent.get("buyerId", "")[:20],
                                secrets.token_hex(8), intent.get("category", "inference"))

                self.daemon._emit("intent_accepted", level="success",
                                 msg=f"ACCEPT — earned +{est_price:.2f} NOM | reason: {reason}")
            else:
                self.daemon._emit("intent_decision",
                                 msg=f"{action.upper()} — {reason}")

            return {
                "action": action,
                "reason": reason,
                "suspicious": decision.get("suspicious", False),
                "model": self.current_model,
                "backend": self.llm._backend or "mock",
                "wallet_balance": self.wallet._balance_nom,
            }
        except Exception as e:
            self.daemon._emit("eval_error", level="error", msg=str(e))
            return {"action": "error", "reason": str(e)}


# ── Output Sanitization ──────────────────────────────────────────

import re

# Patterns to strip from LLM output before sending to QML
_QML_INJECTION_PATTERNS = [
    re.compile(r'Qt\.create\w+', re.I),
    re.compile(r'Component\s*\{', re.I),
    re.compile(r'import\s+Qt', re.I),
    re.compile(r'<script[\s>]', re.I),
    re.compile(r'javascript:', re.I),
    re.compile(r'eval\s*\(', re.I),
]

# Key-like hex patterns that should never leave the system
_KEY_PATTERN = re.compile(r'[0-9a-f]{64,}', re.I)


def _sanitize_llm_output(text: str) -> str:
    """Strip QML/JS injection attempts and key-like strings from LLM output."""
    for pattern in _QML_INJECTION_PATTERNS:
        text = pattern.sub("[filtered]", text)
    text = _KEY_PATTERN.sub("[key-redacted]", text)
    return text


# ── HTTP Handler ──────────────────────────────────────────────────

bridge = DaemonBridge()


class BridgeHandler(BaseHTTPRequestHandler):

    def _cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")

    def _json_response(self, data, status: int = 200):
        body = json.dumps(data).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self._cors_headers()
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _read_body(self) -> dict:
        length = int(self.headers.get("Content-Length", 0))
        if length == 0:
            return {}
        if length > MAX_REQUEST_BYTES:
            return {"_error": "request too large"}
        raw = self.rfile.read(length)
        return json.loads(raw)

    def _check_auth(self) -> bool:
        if not bridge._auth_token:
            return True
        auth = self.headers.get("Authorization", "")
        token = auth.replace("Bearer ", "") if auth.startswith("Bearer ") else auth
        return bridge.check_auth(token)

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors_headers()
        self.end_headers()

    def do_GET(self):
        if not self._check_auth():
            self._json_response({"error": "unauthorized"}, 401)
            return

        path = self.path.split("?")[0]
        params = {}
        if "?" in self.path:
            params = dict(p.split("=") for p in self.path.split("?")[1].split("&") if "=" in p)

        if path == "/health":
            self._json_response(bridge.health())
        elif path == "/status":
            self._json_response(bridge.status())
        elif path == "/wallet":
            self._json_response(bridge.wallet_state())
        elif path == "/agent":
            self._json_response(bridge.agent_state())
        elif path == "/agent/events":
            since = int(params.get("since", 0))
            self._json_response(bridge.agent_events(since))
        elif path == "/agent/audit":
            limit = int(params.get("limit", 50))
            self._json_response(bridge.agent_audit(limit))
        elif path == "/agent/card":
            self._json_response(bridge.agent_card())
        elif path == "/skills":
            category = params.get("category")
            self._json_response(bridge.list_skills(category))
        elif path == "/owner/pending":
            self._json_response(bridge.owner_pending())
        else:
            self._json_response({"error": "not found"}, 404)

    def do_POST(self):
        if not self._check_auth():
            self._json_response({"error": "unauthorized"}, 401)
            return

        body = self._read_body()
        if body.get("_error"):
            self._json_response({"error": body["_error"]}, 400)
            return

        path = self.path

        if path == "/chat":
            message = body.get("message", "")
            if not message:
                self._json_response({"error": "missing 'message' field"}, 400)
                return
            self._json_response(bridge.chat(message))

        elif path == "/model":
            model = body.get("model", "")
            self._json_response(bridge.switch_model(model))

        elif path == "/wallet/fund":
            amount = float(body.get("amount", 0))
            self._json_response(bridge.wallet_fund(amount))

        elif path == "/wallet/freeze":
            self._json_response(bridge.wallet_freeze())

        elif path == "/wallet/unfreeze":
            self._json_response(bridge.wallet_unfreeze())

        elif path == "/wallet/policy":
            self._json_response(bridge.wallet_update_policy(body))

        elif path == "/agent/buy":
            category = body.get("category", "inference")
            task = body.get("task", "")
            budget = float(body.get("budget", 0))
            self._json_response(bridge.agent_buy(category, task, budget))

        elif path == "/agora/intent":
            self._json_response(bridge.agora_evaluate_intent(body))

        elif path == "/skills/invoke":
            name = body.get("skill", "")
            params = body.get("params", {})
            if not name:
                self._json_response({"error": "missing 'skill' field"}, 400)
                return
            self._json_response(bridge.invoke_skill(name, params))

        elif path == "/owner/chat":
            message = body.get("message", "")
            if not message:
                self._json_response({"error": "missing 'message' field"}, 400)
                return
            self._json_response(bridge.owner_chat(message))

        elif path == "/owner/approve":
            request_id = body.get("request_id", "")
            if not request_id:
                self._json_response({"error": "missing 'request_id' field"}, 400)
                return
            self._json_response(bridge.owner_approve(request_id))

        elif path == "/owner/deny":
            request_id = body.get("request_id", "")
            if not request_id:
                self._json_response({"error": "missing 'request_id' field"}, 400)
                return
            self._json_response(bridge.owner_deny(request_id))

        else:
            self._json_response({"error": "not found"}, 404)

    def log_message(self, format, *args):
        pass  # Quiet


def run_server():
    print(f"\n{'='*60}")
    print(f"  daemon-ai Bridge Server")
    print(f"  http://{BRIDGE_HOST}:{BRIDGE_PORT}")
    print(f"{'='*60}\n")

    # Generate auth token
    token = bridge.generate_auth_token()
    print(f"[Bridge] Auth token written to {AUTH_TOKEN_FILE}")

    # Initialize wallet and detect backend
    bridge.initialize()
    print(f"[Bridge] Backend: {bridge.backend}")
    print(f"[Bridge] Model: {bridge.current_model}")

    # Start autonomous daemon in background
    bridge.start_daemon_background()

    print(f"[Bridge] Ready for QML plugin connections\n")

    server = HTTPServer((BRIDGE_HOST, BRIDGE_PORT), BridgeHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[Bridge] Shutting down")
        bridge.wallet.shutdown()
        server.shutdown()


if __name__ == "__main__":
    run_server()
