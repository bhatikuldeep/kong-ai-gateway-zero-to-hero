#!/usr/bin/env bash
# Look up Acme's AI Gateway by name (never "the first gateway": an org can have several)
# and write its data plane endpoints into ../.env.
set -euo pipefail
cd "$(dirname "$0")/.."
source ../.env
api="https://${KONNECT_REGION}.api.konghq.com"
gw=$(curl -sf -H "Authorization: Bearer ${KONNECT_TOKEN}" "${api}/v1/ai-gateways?page%5Bsize%5D=100" \
  | jq -c '.data[] | select(.name=="acme-ai-gateway")')
[ -n "$gw" ] || { echo "acme-ai-gateway not found: run 'make apply' first"; exit 1; }
cp_host=$(jq -r '.endpoints.configuration' <<<"$gw" | sed 's#^https://##; s#/.*##')
tp_host=$(jq -r '.endpoints.telemetry' <<<"$gw" | sed 's#^https://##; s#/.*##')
set_env() { sed -i.bak "s#^$1=.*#$1=$2#" ../.env && rm -f ../.env.bak; }
set_env KONG_CLUSTER_CONTROL_PLANE "${cp_host}:443"
set_env KONG_CLUSTER_SERVER_NAME "${cp_host}"
set_env KONG_CLUSTER_TELEMETRY_ENDPOINT "${tp_host}:443"
set_env KONG_CLUSTER_TELEMETRY_SERVER_NAME "${tp_host}"
echo "endpoints written to .env (control plane ${cp_host})"
