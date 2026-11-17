#!/usr/bin/env bash
# Checks failover behaviour, not model text: who answered (X-Kong-LLM-Model) and the status code.
# Stops Part 1's Ollama container for a moment and always starts it again.
set -uo pipefail
cd "$(dirname "$0")/.."
source ../.env
port=${GATEWAY_PORT:-8000}
url=http://127.0.0.1:${port}/v1/chat/completions
body='{"model": "acme-chat-fallback", "messages": [{"role": "user", "content": "Name one HTTP method."}]}'
compose="docker compose -p acme-aigw"
fail=0
trap '$compose start ollama >/dev/null 2>&1' EXIT

check() { if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (expected $3, got $2)"; fail=1; fi; }
ask() {  # prints: status model total_ms gateway_ms (X-Kong-Proxy-Latency: time spent before the answering model)
  local out
  out=$(curl -s -o /dev/null -D /tmp/acme-h -w '%{http_code} %{time_total}' --max-time 60 "$url" \
    -H 'content-type: application/json' -H "apikey: ${SHOP_APP_KEY}" -d "$body")
  local model gw
  model=$(grep -i '^x-kong-llm-model:' /tmp/acme-h | tr -d '\r' | awk '{print $2}')
  gw=$(grep -i '^x-kong-proxy-latency:' /tmp/acme-h | tr -d '\r' | awk '{print $2}')
  awk -v o="$out" -v m="${model:-none}" -v g="${gw:-0}" 'BEGIN { split(o, a, " "); printf "%s %s %d %d\n", a[1], m, a[2] * 1000, g }'
}

read -r code model ms gw <<<"$(ask)"
check "Ollama answers first" "$code $model" "200 ollama/${LLM_MODEL}"

echo "      stopping Ollama ..."
$compose stop ollama >/dev/null
read -r code model ms gw <<<"$(ask)"
check "Ollama down: Claude answers" "$code $model" "200 anthropic/${CLAUDE_MODEL}"
echo "      first request after the outage: ${ms} ms, of which ${gw} ms waiting for Ollama (connect_timeout)"
check "Anthropic account headers removed" "$(grep -ciE '^anthropic-(organization|workspace)-id:' /tmp/acme-h)" "0"
for i in 1 2 3; do
  read -r code model ms gw <<<"$(ask)"
  check "request $((i + 1)) during the outage: Claude answers" "$code $model" "200 anthropic/${CLAUDE_MODEL}"
  echo "      ${ms} ms, of which ${gw} ms in the gateway"
done

echo "      starting Ollama again ..."
$compose start ollama >/dev/null
until [ "$(docker inspect -f '{{.State.Health.Status}}' acme-aigw-ollama-1 2>/dev/null)" = healthy ]; do sleep 1; done
sleep 11   # fail_timeout is 10 s: after it, Kong tries Ollama again
read -r code model ms gw <<<"$(ask)"
check "Ollama back: it answers again" "$code $model" "200 ollama/${LLM_MODEL}"
exit $fail
