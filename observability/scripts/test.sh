#!/usr/bin/env bash
# make test: send a few requests through Part 1's acme-chat, then check they arrive in Grafana's data
# sources as metrics (Prometheus), traces (Tempo) and logs (Loki). Queries go through Grafana's
# data source proxy, so only Grafana's port is used.
set -uo pipefail
cd "$(dirname "$0")/.."
source ../.env
gw=http://127.0.0.1:${GATEWAY_PORT:-8000}/v1/chat/completions
gf=http://127.0.0.1:${GRAFANA_PORT:-3000}
fail=0
check() { if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (expected $3, got $2)"; fail=1; fi; }
grafana() { curl -sf -u "admin:${GRAFANA_ADMIN_PASSWORD}" "$gf$1" "${@:2}"; }

for _ in 1 2 3; do
  curl -s -o /dev/null "$gw" -H 'content-type: application/json' -H @<(printf "apikey: %s\n" "$SHOP_APP_KEY") \
    -d '{"model": "acme-chat", "messages": [{"role": "user", "content": "Name one HTTP method."}]}'
done
echo "      sent 3 requests to acme-chat; waiting for them to arrive ..."

# Metrics: Prometheus scrapes every 15 s
n=0
for _ in $(seq 1 12); do
  n=$(grafana "/api/datasources/proxy/uid/prometheus/api/v1/query" --data-urlencode 'query=sum(kong_ai_llm_requests_total)' -G \
      | jq -r '.data.result[0].value[1] // "0"' | cut -d. -f1)
  [ "${n:-0}" -gt 0 ] && break; sleep 5
done
check "metrics in Prometheus (kong_ai_llm_requests_total)" "$([ "${n:-0}" -gt 0 ] && echo yes || echo no)" "yes"

# Traces in Tempo
t=0
for _ in $(seq 1 12); do
  t=$(grafana "/api/datasources/proxy/uid/tempo/api/search?limit=5" | jq '.traces | length')
  [ "${t:-0}" -gt 0 ] && break; sleep 5
done
check "traces in Tempo" "$([ "${t:-0}" -gt 0 ] && echo yes || echo no)" "yes"

# Logs in Loki: traffic (one structured line per request, from the OpenTelemetry policy) and container
# output (the data plane's own log, through Alloy)
loki_count() {
  grafana "/api/datasources/proxy/uid/loki/loki/api/v1/query_range" -G --data-urlencode "query=$1" \
    --data-urlencode "start=$(( $(date +%s) - 600 ))000000000" | jq '[.data.result[].values[]] | length'
}
for q in '{service_name="kong-ai-gateway"}:traffic logs in Loki' '{container="kong"}:container logs in Loki'; do
  l=0
  for _ in $(seq 1 12); do l=$(loki_count "${q%%:*}"); [ "${l:-0}" -gt 0 ] && break; sleep 5; done
  check "${q#*:} (${q%%:*})" "$([ "${l:-0}" -gt 0 ] && echo yes || echo no)" "yes"
done

check "Kong's AI Gateway dashboard loaded" "$(grafana '/api/search?query=Kong%20AI%20Gateway' | jq 'length > 0')" "true"
echo "      Grafana: $gf (user admin, password GRAFANA_ADMIN_PASSWORD in .env)"
exit $fail
