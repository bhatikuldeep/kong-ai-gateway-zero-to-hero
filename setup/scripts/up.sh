#!/usr/bin/env bash
# make up: everything needed to run 000, in order. Safe to run again: it only changes what's missing.
set -euo pipefail
cd "$(dirname "$0")/.."
env_file=../.env
set_env() { sed -i.bak "s#^$1=.*#$1=$2#" "$env_file" && rm -f "$env_file.bak"; }

# 1. Tools, Docker and the Konnect token
command -v kongctl >/dev/null || { echo "kongctl not found: run 'mise install' in the repository root"; exit 1; }
docker info >/dev/null 2>&1 || { echo "Docker is not running"; exit 1; }
set -a; source "$env_file"; set +a
[ -n "${KONNECT_TOKEN:-}" ] || { echo "Set KONNECT_TOKEN in .env"; exit 1; }

# 2. Data plane certificate and the shop app's API key (created once)
mkdir -p certs
[ -f certs/tls.key ] || openssl req -new -x509 -nodes -newkey rsa:2048 -days 365 \
  -subj "/CN=acme-dp" -keyout certs/tls.key -out certs/tls.crt 2>/dev/null
[ -n "${SHOP_APP_KEY:-}" ] || { set_env SHOP_APP_KEY "$(openssl rand -hex 16)"; set -a; source "$env_file"; set +a; }

# 3. Acme's AI Gateway in Konnect: show the changes, then apply them
#    (--base-dir lets !file read the certificate in setup/certs and nothing outside setup/)
kongctl plan --mode apply -f konnect/ai-gateway.yaml --base-dir . \
  --pat "$KONNECT_TOKEN" --region "$KONNECT_REGION" --output-file plan.json
if [ "$(jq '.summary.total_changes' plan.json)" -gt 0 ]; then
  kongctl apply --plan plan.json --pat "$KONNECT_TOKEN" --region "$KONNECT_REGION"
else
  echo "Konnect is up to date"
fi
rm -f plan.json

# 4. The gateway's connection details, looked up by name (an org can have several gateways)
gw=$(curl -sf -H "Authorization: Bearer ${KONNECT_TOKEN}" \
  "https://${KONNECT_REGION}.api.konghq.com/v1/ai-gateways?page%5Bsize%5D=100" \
  | jq -c '.data[] | select(.name=="acme-ai-gateway")')
[ -n "$gw" ] || { echo "acme-ai-gateway not found in Konnect"; exit 1; }
cp_host=$(jq -r '.endpoints.configuration' <<<"$gw" | sed 's#^https://##; s#/.*##')
tp_host=$(jq -r '.endpoints.telemetry' <<<"$gw" | sed 's#^https://##; s#/.*##')
set_env AI_GATEWAY_ID "$(jq -r '.id' <<<"$gw")"   # later episodes attach to this gateway
set_env KONG_CLUSTER_CONTROL_PLANE "${cp_host}:443"
set_env KONG_CLUSTER_SERVER_NAME "${cp_host}"
set_env KONG_CLUSTER_TELEMETRY_ENDPOINT "${tp_host}:443"
set_env KONG_CLUSTER_TELEMETRY_SERVER_NAME "${tp_host}"

# 5. The containers (the first start downloads the model).
#    Re-read .env first: values loaded in step 1 are stale, and they would override the file in Compose.
set -a; source "$env_file"; set +a
docker compose --env-file "$env_file" up -d --wait
echo "Ready: run 'make test'"
