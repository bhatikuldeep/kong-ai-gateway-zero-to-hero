#!/usr/bin/env bash
# Checks behaviour, not exact model text (a model answers differently every time).
set -uo pipefail
cd "$(dirname "$0")/.."
source ../.env
port=${GATEWAY_PORT:-8000}
url=http://127.0.0.1:${port}/v1/chat/completions
body='{"model": "acme-chat", "messages": [{"role": "user", "content": "Name one HTTP method."}]}'
fail=0

# Make sure it's Kong answering on the port, not another program.
if ! curl -s -o /dev/null -D - --max-time 5 "http://127.0.0.1:${port}/" | grep -qi '^x-kong-'; then
  echo "FAIL  no Kong gateway on port ${port}. Is 'make up' running? If another program uses the port, set GATEWAY_PORT in .env."
  exit 1
fi
check() { if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (expected $3, got $2)"; fail=1; fi; }

code=$(curl -s -o /dev/null -w '%{http_code}' $url -H 'content-type: application/json' -d "$body")
check "no API key is rejected" "$code" 401

resp=$(curl -s -D /tmp/acme-h -w '\n%{http_code} %{time_total}' $url -H 'content-type: application/json' -H "apikey: ${SHOP_APP_KEY}" -d "$body")
read -r code total <<<"$(tail -n1 <<<"$resp")"
check "shop-app key gets an answer" "$code" 200
model=$(grep -i '^x-kong-llm-model:' /tmp/acme-h | tr -d '\r' | awk '{print $2}')
check "answered by the local model" "$model" "ollama/${LLM_MODEL}"
tokens=$(sed '$d' <<<"$resp" | jq -r '.usage.total_tokens // 0')
[ "${tokens:-0}" -gt 0 ] && echo "PASS  token usage reported (${tokens} tokens)" || { echo "FAIL  no token usage"; fail=1; }
kong_ms=$(grep -i '^x-kong-proxy-latency:' /tmp/acme-h | tr -d '\r' | awk '{print $2}')
model_ms=$(grep -i '^x-kong-upstream-latency:' /tmp/acme-h | tr -d '\r' | awk '{print $2}')
ms=$(awk -v t="$total" 'BEGIN { printf "%d", t * 1000 }')
echo "      round trip ${ms} ms on this machine (model ${model_ms} ms, gateway ${kong_ms} ms)"
exit $fail
