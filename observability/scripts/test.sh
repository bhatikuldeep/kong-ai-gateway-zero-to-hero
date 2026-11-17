#!/usr/bin/env bash
# make test: send requests through Part 1's acme-chat and check they arrive in Grafana's data sources as
# metrics (Prometheus), traces (Tempo) and logs (Loki). Only data newer than the start of the test counts.
# A request is sent on every check, so a data plane that just received the policies is covered too.
# Queries go through Grafana's data source proxy, so only Grafana's port is used.
set -uo pipefail
cd "$(dirname "$0")/.."
source ../.env
gw=http://127.0.0.1:${GATEWAY_PORT:-8000}/v1/chat/completions
gf=http://127.0.0.1:${GRAFANA_PORT:-3000}
start=$(date +%s)
fail=0
check() { if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (expected $3, got $2)"; fail=1; fi; }
grafana() { curl -sf -u "admin:${GRAFANA_ADMIN_PASSWORD}" "$gf$1" "${@:2}"; }
ask() {
  curl -s -o /dev/null "$gw" -H 'content-type: application/json' -H @<(printf "apikey: %s\n" "$SHOP_APP_KEY") \
    -d '{"model": "acme-chat", "messages": [{"role": "user", "content": "Name one HTTP method."}]}'
}
# wait_for <label> <command printing a number>: send a request, check, up to 2 minutes
wait_for() {
  local n=0
  for _ in $(seq 1 24); do ask; n=$(eval "$2"); [ "${n:-0}" -gt 0 ] && break; sleep 5; done
  check "$1" "$([ "${n:-0}" -gt 0 ] && echo yes || echo no)" "yes"
}

echo "      sending requests to acme-chat and waiting for them to arrive ..."
# Metrics: requests counted since the test started (Prometheus scrapes every 15 s)
wait_for "metrics in Prometheus (kong_ai_llm_requests_total)" \
  "grafana /api/datasources/proxy/uid/prometheus/api/v1/query -G --data-urlencode \"query=sum(increase(kong_ai_llm_requests_total[\$(( \$(date +%s) - start + 30 ))s]))\" | jq -r '.data.result[0].value[1] // \"0\"' | cut -d. -f1"
# Traces: any trace that started after the test did
wait_for "traces in Tempo" \
  "grafana \"/api/datasources/proxy/uid/tempo/api/search?limit=5&start=\$start&end=\$(( \$(date +%s) + 60 ))\" | jq '.traces | length'"
# Logs: traffic (one structured line per request, from the OpenTelemetry policy) and container output
# (the data plane's own log, through Alloy)
loki_count() {
  grafana "/api/datasources/proxy/uid/loki/loki/api/v1/query_range" -G --data-urlencode "query=$1" \
    --data-urlencode "start=${start}000000000" | jq '[.data.result[].values[]] | length'
}
wait_for 'traffic logs in Loki ({service_name="kong-ai-gateway"})' "loki_count '{service_name=\"kong-ai-gateway\"}'"
wait_for 'container logs in Loki ({container="kong"})' "loki_count '{container=\"kong\"}'"

check "Kong's AI Gateway dashboard loaded" "$(grafana '/api/search?query=Kong%20AI%20Gateway' | jq 'length > 0')" "true"
echo "      Grafana: $gf (user admin, password GRAFANA_ADMIN_PASSWORD in .env)"
exit $fail
