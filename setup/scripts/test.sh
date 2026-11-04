#!/usr/bin/env bash
# Checks behaviour, not exact model text (a model answers differently every time).
set -uo pipefail
cd "$(dirname "$0")/.."
source ../.env
url=http://127.0.0.1:8000/v1/chat/completions
body='{"model": "acme-chat", "messages": [{"role": "user", "content": "Name one HTTP method."}]}'
fail=0
check() { if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (expected $3, got $2)"; fail=1; fi; }

code=$(curl -s -o /dev/null -w '%{http_code}' $url -H 'content-type: application/json' -d "$body")
check "no API key is rejected" "$code" 401

start=$(date +%s)
resp=$(curl -s -D /tmp/acme-h -w '\n%{http_code}' $url -H 'content-type: application/json' -H "apikey: ${SHOP_APP_KEY}" -d "$body")
code=$(tail -n1 <<<"$resp")
check "shop-app key gets an answer" "$code" 200
model=$(grep -i '^x-kong-llm-model:' /tmp/acme-h | tr -d '\r' | awk '{print $2}')
check "answered by the local model" "$model" "ollama/${LLM_MODEL}"
tokens=$(sed '$d' <<<"$resp" | jq -r '.usage.total_tokens // 0')
[ "${tokens:-0}" -gt 0 ] && echo "PASS  token usage reported (${tokens} tokens)" || { echo "FAIL  no token usage"; fail=1; }
echo "      round trip $(( $(date +%s) - start ))s on this machine"
exit $fail
