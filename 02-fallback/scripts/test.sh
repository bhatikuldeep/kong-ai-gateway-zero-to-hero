#!/usr/bin/env bash
# Checks behaviour, not model text: who answered (X-Kong-LLM-Model) and the status code.
# 1. Failover to Claude: stops Part 1's Ollama container for a moment and always starts it again.
# 2. Load balancing: each strategy against the stand-in models, which can be switched to failing.
set -uo pipefail
cd "$(dirname "$0")/.."
source ../.env
port=${GATEWAY_PORT:-8000}
url=http://127.0.0.1:${port}/v1/chat/completions
body='{"model": "acme-chat-fallback", "messages": [{"role": "user", "content": "Name one HTTP method."}]}'
compose="docker compose -p acme-aigw"
fail=0
tmp=$(mktemp -d)
# mock <down|up|hits> <target>: switch a stand-in model to failing (503) and back; prints its request count
mock() { docker compose -f compose.yaml exec -T mock-llm wget -qO- "http://127.0.0.1:8081/$1/$2" </dev/null; }
trap '$compose start ollama >/dev/null 2>&1; for t in prio-primary prio-standby nr-primary nb-primary; do mock up $t >/dev/null 2>&1; done; rm -rf "$tmp"' EXIT

check() { if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (expected $3, got $2)"; fail=1; fi; }
range() { if [ "$2" -ge "$3" ] && [ "$2" -le "$4" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got $2, expected $3 to $4)"; fail=1; fi; }
ask() {  # prints: status model total_ms gateway_ms (X-Kong-Proxy-Latency: time spent before the answering model)
  local out
  out=$(curl -s -o /dev/null -D "$tmp/h" -w '%{http_code} %{time_total}' --max-time 60 "$url" \
    -H 'content-type: application/json' -H "apikey: ${SHOP_APP_KEY}" -d "$body")
  local model gw
  model=$(grep -i '^x-kong-llm-model:' "$tmp/h" | tr -d '\r' | awk '{print $2}')
  gw=$(grep -i '^x-kong-proxy-latency:' "$tmp/h" | tr -d '\r' | awk '{print $2}')
  awk -v o="$out" -v m="${model:-none}" -v g="${gw:-0}" 'BEGIN { split(o, a, " "); printf "%s %s %d %d\n", a[1], m, a[2] * 1000, g }'
}

# --- Load balancing ------------------------------------------------------------------------------------
# who <model> [curl args]: the target that answered, or the status code when it was not a 200
who() {
  local m=$1; shift
  local code hf; hf=$(mktemp "$tmp/w.XXXXXX")
  code=$(curl -s -o /dev/null -D "$hf" -w '%{http_code}' --max-time 30 "$url" -H 'content-type: application/json' \
    -H "apikey: ${SHOP_APP_KEY}" "$@" \
    -d "{\"model\": \"$m\", \"messages\": [{\"role\": \"user\", \"content\": \"${PROMPT:-Hello}\"}]}")
  if [ "$code" = 200 ]; then grep -i '^x-kong-llm-model:' "$hf" | tr -d '\r' | awk '{print $2}' | sed 's#^[^/]*/##'
  else echo "$code"; fi
}
# tally <model> <n> [curl args]: "target count" for n requests, one per line
tally() { local m=$1 n=$2; shift 2; for _ in $(seq 1 "$n"); do who "$m" "$@"; done | sort | uniq -c | awk '{print $2" "$1}'; }
count() { awk -v t="$2" '$1==t {print $2}' <<<"$1" | grep . || echo 0; }
show() { echo "      $1: $(tr '\n' ' ' <<<"$2" | sed 's/ $//')"; }

echo "Priority with failover and a circuit breaker (acme-lb-priority)"
r=$(tally acme-lb-priority 20); show "20 requests" "$r"
check "the highest weight answers everything while it is healthy" "$(count "$r" prio-primary)" 20
mock down prio-primary >/dev/null; h0=$(mock hits prio-primary)
r=$(tally acme-lb-priority 20); h1=$(mock hits prio-primary); show "primary returns 503, 20 requests" "$r"
check "primary down: the standby answers every request" "$(count "$r" prio-standby)" 20
echo "      requests that reached the failing primary: $((h1 - h0)) (max_fails is 3, counted in each of the 2 nginx workers)"
range "the circuit breaker stops trying the primary" "$((h1 - h0))" 3 6
mock up prio-primary >/dev/null; sleep 11   # fail_timeout is 10 s
r=$(tally acme-lb-priority 10); show "primary healthy again, after fail_timeout, 10 requests" "$r"
check "after fail_timeout the primary takes the traffic back" "$(count "$r" prio-primary)" 10

echo
echo "Failover without non_idempotent (acme-lb-no-retry)"
mock down nr-primary >/dev/null
r=$(tally acme-lb-no-retry 10); show "primary returns 503, 10 requests" "$r"
check "chat requests are POSTs: without non_idempotent the 503 goes back to the app" "$(count "$r" 503)" 10
mock up nr-primary >/dev/null

echo
echo "Failover without a circuit breaker (acme-lb-no-breaker, max_fails 0)"
mock down nb-primary >/dev/null; h0=$(mock hits nb-primary)
r=$(tally acme-lb-no-breaker 20); h1=$(mock hits nb-primary); show "primary returns 503, 20 requests" "$r"
check "the standby still answers every request" "$(count "$r" nb-standby)" 20
check "but every request tries the failing primary first" "$((h1 - h0))" 20
mock up nb-primary >/dev/null

echo
echo "Every target down (acme-lb-priority)"
mock down prio-primary >/dev/null; mock down prio-standby >/dev/null
code=$(who acme-lb-priority); echo "      status: $code"
if [ "$code" -ge 500 ] 2>/dev/null; then echo "PASS  with no healthy target the app gets an error ($code)"
else echo "FAIL  with no healthy target: expected a 5xx, got $code"; fail=1; fi
mock up prio-primary >/dev/null; mock up prio-standby >/dev/null

echo
echo "Weighted round-robin, 90/10 (acme-lb-canary)"
r=$(tally acme-lb-canary 100); show "100 requests" "$r"
range "the candidate gets about 10%" "$(count "$r" rr-candidate)" 4 16

echo
echo "Consistent hashing on X-Acme-User (acme-lb-sticky)"
r=$(tally acme-lb-sticky 10 -H 'X-Acme-User: user-7'); show "user-7, 10 requests" "$r"
check "the same user always reaches the same target" "$(wc -l <<<"$r" | tr -d ' ')" 1
n=$(for u in $(seq 1 12); do who acme-lb-sticky -H "X-Acme-User: user-$u"; done | sort -u | wc -l | tr -d ' ')
range "12 users spread over $n of the 3 targets" "$n" 2 3

echo
echo "Lowest latency (acme-lb-fastest; lat-slow waits 2 s)"
r=$(tally acme-lb-fastest 20); show "20 requests" "$r"
range "the faster target takes most requests" "$(count "$r" lat-fast)" 16 20

echo
echo "Lowest usage, total tokens (acme-lb-tokens; use-big reports 100x the tokens)"
r=$(tally acme-lb-tokens 20); show "20 requests" "$r"
range "the target that used fewer tokens takes most requests" "$(count "$r" use-small)" 15 20

echo
echo "Least connections (acme-lb-least-conn; lc-slow waits 2 s)"
since=$(date -u +%Y-%m-%dT%H:%M:%SZ)
for i in $(seq 1 20); do ( who acme-lb-least-conn > "$tmp/lc.$i" ) & sleep 0.2; done; wait
r=$(cat "$tmp"/lc.* | sort | uniq -c | awk '{print $2" "$1}'); show "20 overlapping requests" "$r"
errors=$($compose logs --since "$since" kong 2>/dev/null | grep -c 'least-connections.lua' || true)
echo "      data plane log lines from least-connections.lua: $errors"
f=$(count "$r" lc-fast); s=$(count "$r" lc-slow)
if [ "$f" -gt $((s + 4)) ]; then echo "PASS  the target with spare capacity takes more requests ($f vs $s)"
else echo "NOTE  least-connections split $f/$s, like round-robin, on this version (see README); not counted as a failure"; fi

echo
echo "Semantic routing (acme-lb-semantic)"
r=$(PROMPT="Where is my order? It was due yesterday." who acme-lb-semantic); r2=$(PROMPT="Can I return these shoes and get a refund?" who acme-lb-semantic)
show "two questions about orders" "$r $r2"; check "order questions go to the orders model" "$r $r2" "sem-orders sem-orders"
r=$(PROMPT="Why does my Python function raise a KeyError?" who acme-lb-semantic); r2=$(PROMPT="How do I deploy a REST API from a CI pipeline?" who acme-lb-semantic)
show "two questions about code" "$r $r2"; check "code questions go to the code model" "$r $r2" "sem-code sem-code"


echo
echo "Failover to Claude (acme-chat-fallback)"
read -r code model ms gw <<<"$(ask)"
check "Ollama answers first" "$code $model" "200 ollama/${LLM_MODEL}"

echo "      stopping Ollama ..."
$compose stop ollama >/dev/null 2>&1
read -r code model ms gw <<<"$(ask)"
check "Ollama down: Claude answers" "$code $model" "200 anthropic/${CLAUDE_MODEL}"
echo "      first request after the outage: ${ms} ms, of which ${gw} ms waiting for Ollama (connect_timeout)"
if [ "$code" = 200 ]; then  # only meaningful on an answer from Claude
  check "Anthropic account headers removed" "$(grep -ciE '^anthropic-(organization|workspace)-id:' "$tmp/h")" "0"
fi
for i in 1 2 3; do
  read -r code model ms gw <<<"$(ask)"
  check "request $((i + 1)) during the outage: Claude answers" "$code $model" "200 anthropic/${CLAUDE_MODEL}"
  echo "      ${ms} ms, of which ${gw} ms in the gateway"
done

echo "      starting Ollama again ..."
$compose start ollama >/dev/null 2>&1
until [ "$(docker inspect -f '{{.State.Health.Status}}' acme-aigw-ollama-1 2>/dev/null)" = healthy ]; do sleep 1; done
# Kong tries Ollama again after fail_timeout (10 s). Each nginx worker may also have cached that the name
# "ollama" didn't resolve while the container was stopped, so allow up to 60 s and report how long it took.
back=$(date +%s); code=""
for _ in $(seq 1 30); do
  sleep 2
  read -r code model ms gw <<<"$(ask)"
  [ "$code $model" = "200 ollama/${LLM_MODEL}" ] && read -r code model ms gw <<<"$(ask)" && [ "$code $model" = "200 ollama/${LLM_MODEL}" ] && break
done
echo "      Ollama answered again (twice in a row) $(( $(date +%s) - back )) s after it was healthy"
check "Ollama back: it answers again" "$code $model" "200 ollama/${LLM_MODEL}"

echo
[ "$fail" = 0 ] && echo "All checks passed" || echo "Some checks failed"
exit $fail
