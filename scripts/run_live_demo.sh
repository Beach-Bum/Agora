#!/usr/bin/env bash
# LP-0008 Live Demo — Screen Recording Version
# Types each command visibly before executing it
# no set -e — keep going if a command fails

G="\033[32m"
Y="\033[33m"
C="\033[36m"
R="\033[31m"
W="\033[0m"
B="\033[1m"
D="\033[2m"

# ── Simulate fast but natural typing ─────────────────────────
type_cmd() {
    local cmd="$1"
    echo ""
    printf "${C}\$ ${W}"
    for (( i=0; i<${#cmd}; i++ )); do
        local char="${cmd:$i:1}"
        printf "%s" "$char"
        # Fast typing with slight variation
        local delay=$(awk "BEGIN{srand(); printf \"%.3f\", 0.008 + rand()*0.02}")
        if [[ "$char" == " " ]]; then
            delay=$(awk "BEGIN{srand(); printf \"%.3f\", 0.02 + rand()*0.03}")
        elif [[ "$char" == "|" || "$char" == "'" || "$char" == "{" ]]; then
            delay=$(awk "BEGIN{srand(); printf \"%.3f\", 0.03 + rand()*0.04}")
        fi
        sleep "$delay"
    done
    echo ""
    eval "$cmd"
}

pause() { sleep "${1:-1}"; }

banner() {
    echo ""
    echo -e "${G}════════════════════════════════════════════════════════════════${W}"
    echo -e "${G}  $1${W}"
    echo -e "${G}════════════════════════════════════════════════════════════════${W}"
    echo ""
    pause 1
}

# ── INTRO ────────────────────────────────────────────────────
clear
banner "LP-0008: daemon-ai on Agora — LIVE DEMO"
echo -e "  ${B}All operations are REAL — no mocks, no simulations${W}"
echo -e "  ${D}Blockchain:  logos-blockchain-node (Groth16 ZK proofs)${W}"
echo -e "  ${D}LLM:         Ollama llama3.2:3b (local inference)${W}"
echo -e "  ${D}Messaging:   Waku nwaku (P2P relay over libp2p)${W}"
echo ""
pause 1

# ── SERVICE CHECK ────────────────────────────────────────────
banner "Service Check"

echo -e "  ${Y}[1]${W} Blockchain node"
type_cmd "curl -s http://localhost:18080/cryptarchia/info | python3 -m json.tool"
pause 1

echo ""
echo -e "  ${Y}[2]${W} Ollama LLM"
type_cmd "curl -s http://localhost:11434/api/tags | python3 -c \"import sys,json; d=json.load(sys.stdin); [print(f'    {m[\\\"name\\\"]}') for m in d['models']]\""
pause 1

echo ""
echo -e "  ${Y}[3]${W} Waku messaging"
type_cmd "curl -s http://localhost:8645/debug/v1/info | python3 -c \"import sys,json; d=json.load(sys.stdin); print(f'    peer: {d[\\\"listenAddresses\\\"][0][:60]}...')\""
pause 1

# ── PART 1: REAL BLOCKCHAIN ─────────────────────────────────
banner "Part 1: Real Blockchain (logos-blockchain-node)"

echo -e "  ${Y}[1]${W} Genesis wallet balance"
type_cmd "curl -s http://localhost:18080/wallet/2e03b2eff5a45478e7e79668d2a146cf2c5c7925bce927f2b1c67f2ab4fc0d26/balance | python3 -m json.tool"
pause 1

echo ""
echo -e "  ${Y}[2]${W} Token transfer — 5 NOM with real Groth16 ZK proof"
type_cmd "curl -s -X POST http://localhost:18080/wallet/transactions/transfer-funds -H 'Content-Type: application/json' -d '{\"funding_public_keys\":[\"2e03b2eff5a45478e7e79668d2a146cf2c5c7925bce927f2b1c67f2ab4fc0d26\"],\"recipient_public_key\":\"ed266e6e887b9b97059dc1aa1b7b2e19b934291753c6336a163fe4ebaa28e717\",\"change_public_key\":\"2e03b2eff5a45478e7e79668d2a146cf2c5c7925bce927f2b1c67f2ab4fc0d26\",\"amount\":5}' | python3 -m json.tool"
echo -e "      ${D}Waiting for block confirmation...${W}"
sleep 3

echo ""
echo -e "  ${Y}[3]${W} Verify balances after transfer"
type_cmd "curl -s http://localhost:18080/wallet/2e03b2eff5a45478e7e79668d2a146cf2c5c7925bce927f2b1c67f2ab4fc0d26/balance | python3 -c \"import sys,json; d=json.load(sys.stdin); print(f'    Genesis: {d[\\\"balance\\\"]} NOM  ({len(d[\\\"notes\\\"])} UTXO notes)')\""
pause 1
type_cmd "curl -s http://localhost:18080/wallet/ed266e6e887b9b97059dc1aa1b7b2e19b934291753c6336a163fe4ebaa28e717/balance | python3 -c \"import sys,json; d=json.load(sys.stdin); print(f'    SDP:     {d[\\\"balance\\\"]} NOM  ({len(d[\\\"notes\\\"])} UTXO notes)')\""
pause 1

# ── PART 2: REAL LLM INFERENCE ──────────────────────────────
banner "Part 2: Real LLM Inference (Ollama)"

echo -e "  ${Y}[1]${W} Agent evaluates a buy intent using local LLM"
type_cmd "curl -s http://localhost:11434/api/generate -d '{\"model\":\"llama3.2:3b\",\"prompt\":\"You are an autonomous AI agent on a decentralized marketplace. A buyer wants inference services for 5 NOM. Should you accept? Reply in 2 sentences.\",\"stream\":false}' | python3 -c \"import sys,json; d=json.load(sys.stdin); print(f'    Model:    llama3.2:3b'); print(f'    Tokens:   {d.get(\\\"eval_count\\\",0)}'); print(f'    Response: {d[\\\"response\\\"].strip()[:200]}')\""
pause 1

echo ""
echo -e "  ${Y}[2]${W} Agent generates a task result"
type_cmd "curl -s http://localhost:11434/api/generate -d '{\"model\":\"llama3.2:3b\",\"prompt\":\"Explain zero-knowledge proofs in 3 sentences for a technical audience.\",\"stream\":false}' | python3 -c \"import sys,json,hashlib; d=json.load(sys.stdin); r=d['response'].strip(); h=hashlib.sha256(r.encode()).hexdigest(); print(f'    Tokens:   {d.get(\\\"eval_count\\\",0)}'); print(f'    Hash:     {h[:32]}...'); print(f'    Response: {r[:200]}')\""
pause 1

# ── PART 3: REAL P2P MESSAGING ──────────────────────────────
banner "Part 3: Real P2P Messaging (Waku)"

echo -e "  ${Y}[1]${W} Publish Agent Card to discovery topic"
type_cmd "python3 -c \"
import httpx, json, base64, time
card = {'name':'daemon-ai','version':'1.0.0','skills':['inference','research','code'],'protocol':'A2A/1.0.0'}
payload = base64.b64encode(json.dumps(card).encode()).decode()
msg = {'payload': payload, 'contentTopic': '/agora/1/capabilities/json', 'timestamp': int(time.time()*1e9)}
r = httpx.post('http://localhost:8645/relay/v1/auto/messages', json=msg, timeout=10)
print(f'    Published: {r.status_code}')
print(f'    Topic:     /agora/1/capabilities/json')
print(f'    Card:      {json.dumps(card)[:80]}...')
\""
pause 1

echo ""
echo -e "  ${Y}[2]${W} Broadcast buy intent via relay"
type_cmd "python3 -c \"
import httpx, json, base64, time
intent = {'type':'buy_intent','buyer':'ed266e6e...','category':'inference','budget_nom':5.0,'task':'Summarize AI agent research'}
payload = base64.b64encode(json.dumps(intent).encode()).decode()
msg = {'payload': payload, 'contentTopic': '/agora/1/intents/json', 'timestamp': int(time.time()*1e9)}
r = httpx.post('http://localhost:8645/relay/v1/auto/messages', json=msg, timeout=10)
print(f'    Published: {r.status_code}')
print(f'    Topic:     /agora/1/intents/json')
print(f'    Budget:    {intent[\\\"budget_nom\\\"]} NOM')
\""
pause 1

echo ""
echo -e "  ${Y}[3]${W} Read messages from Waku store (Node 2: port 8646)"
type_cmd "python3 -c \"
import httpx, json, base64
r = httpx.get('http://localhost:8646/store/v3/messages?includeData=true', timeout=10)
data = r.json()
print(f'    Messages in store: {len(data[\\\"messages\\\"])}')
for m in data['messages']:
    if 'message' in m:
        try:
            decoded = base64.b64decode(m['message'].get('payload','')).decode()
            parsed = json.loads(decoded)
            print(f'      → {m[\\\"message\\\"][\\\"contentTopic\\\"]}: {json.dumps(parsed)[:80]}')
        except: pass
\""
pause 1

# ── PART 4: FULL TRADE FLOW ─────────────────────────────────
banner "Part 4: Full Trade Flow (Blockchain + LLM + Messaging)"
echo -e "  ${D}Buyer broadcasts intent → Seller LLM evaluates →${W}"
echo -e "  ${D}Blockchain escrow → Delivery → Settlement${W}"
echo ""
pause 1

echo -e "  ${Y}[1]${W} Seller LLM evaluates and generates response"
type_cmd "curl -s http://localhost:11434/api/generate -d '{\"model\":\"llama3.2:3b\",\"prompt\":\"Summarize recent advances in decentralized AI agent marketplaces in 3 sentences.\",\"stream\":false}' | python3 -c \"import sys,json,hashlib; d=json.load(sys.stdin); r=d['response'].strip(); h=hashlib.sha256(r.encode()).hexdigest(); print(f'    Generated: {d.get(\\\"eval_count\\\",0)} tokens'); print(f'    Hash:      {h[:32]}...'); print(f'    Result:    {r[:160]}')\""
pause 1

echo ""
echo -e "  ${Y}[2]${W} Payment: 2 NOM via shielded ZK transfer"
type_cmd "curl -s -X POST http://localhost:18080/wallet/transactions/transfer-funds -H 'Content-Type: application/json' -d '{\"funding_public_keys\":[\"2e03b2eff5a45478e7e79668d2a146cf2c5c7925bce927f2b1c67f2ab4fc0d26\"],\"recipient_public_key\":\"ed266e6e887b9b97059dc1aa1b7b2e19b934291753c6336a163fe4ebaa28e717\",\"change_public_key\":\"2e03b2eff5a45478e7e79668d2a146cf2c5c7925bce927f2b1c67f2ab4fc0d26\",\"amount\":2}' | python3 -c \"import sys,json; d=json.load(sys.stdin); print(f'    TX hash: {d[\\\"hash\\\"]}'); print(f'    Amount:  2 NOM (shielded ZK transfer)')\""
echo -e "      ${D}Waiting for block confirmation...${W}"
sleep 3

echo ""
echo -e "  ${Y}[3]${W} Delivery notification via Waku"
type_cmd "python3 -c \"
import httpx, json, base64, time
delivery = {'type':'delivery','seller':'2e03b2ef...','amount_nom':2,'status':'completed'}
payload = base64.b64encode(json.dumps(delivery).encode()).decode()
msg = {'payload': payload, 'contentTopic': '/agora/1/delivery/json', 'timestamp': int(time.time()*1e9)}
r = httpx.post('http://localhost:8645/relay/v1/auto/messages', json=msg, timeout=10)
print(f'    Notification sent: {r.status_code}')
print(f'    Topic: /agora/1/delivery/json')
print(f'    Trade complete — all on real infrastructure')
\""
pause 1

echo ""
echo -e "  ${Y}[4]${W} Final balances"
type_cmd "curl -s http://localhost:18080/wallet/2e03b2eff5a45478e7e79668d2a146cf2c5c7925bce927f2b1c67f2ab4fc0d26/balance | python3 -c \"import sys,json; d=json.load(sys.stdin); print(f'    Genesis: {d[\\\"balance\\\"]} NOM')\""
type_cmd "curl -s http://localhost:18080/wallet/ed266e6e887b9b97059dc1aa1b7b2e19b934291753c6336a163fe4ebaa28e717/balance | python3 -c \"import sys,json; d=json.load(sys.stdin); print(f'    SDP:     {d[\\\"balance\\\"]} NOM')\""
pause 1

# ── PART 5: AGENT STATUS + SKILLS ────────────────────────────
banner "Part 5: Agent Framework (21 Skills)"

echo -e "  ${Y}[1]${W} Agent status"
type_cmd "python3 scripts/agora_cli.py status"
pause 1

echo ""
echo -e "  ${Y}[2]${W} Skill registry — 21 composable skills"
type_cmd "python3 scripts/agora_cli.py skills"
pause 1

echo ""
echo -e "  ${Y}[3]${W} A2A v1.0.0 Agent Card"
type_cmd "python3 scripts/agora_cli.py card | head -25"
pause 1

echo ""
echo -e "  ${Y}[4]${W} Third transfer — 1 NOM to SDP wallet"
type_cmd "curl -s -X POST http://localhost:18080/wallet/transactions/transfer-funds -H 'Content-Type: application/json' -d '{\"funding_public_keys\":[\"2e03b2eff5a45478e7e79668d2a146cf2c5c7925bce927f2b1c67f2ab4fc0d26\"],\"recipient_public_key\":\"ed266e6e887b9b97059dc1aa1b7b2e19b934291753c6336a163fe4ebaa28e717\",\"change_public_key\":\"2e03b2eff5a45478e7e79668d2a146cf2c5c7925bce927f2b1c67f2ab4fc0d26\",\"amount\":1}' | python3 -c \"import sys,json; d=json.load(sys.stdin); print(f'    TX hash: {d[\\\"hash\\\"]}'); print(f'    Amount:  1 NOM (shielded ZK transfer)')\""
echo -e "      ${D}Waiting for block confirmation...${W}"
sleep 3

# ── CLOSING ──────────────────────────────────────────────────
banner "LIVE DEMO COMPLETE"
echo -e "  ${G}✓${W} Real blockchain: logos-blockchain-node (Groth16 ZK proofs)"
echo -e "  ${G}✓${W} Real LLM inference: Ollama llama3.2:3b (local, no API key)"
echo -e "  ${G}✓${W} Real P2P messaging: Waku relay (libp2p)"
echo -e "  ${G}✓${W} Real token transfers: shielded UTXO with ZK proofs"
echo -e "  ${G}✓${W} Full trade flow: intent → evaluation → payment → delivery"
echo -e "  ${G}✓${W} 21 composable agent skills"
echo ""
echo -e "  ${C}github.com/Beach-Bum/Agora${W}"
echo ""
pause 2
