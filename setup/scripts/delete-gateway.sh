#!/usr/bin/env bash
# Delete Acme's AI Gateway (and everything inside it) from Konnect, looked up by name.
set -euo pipefail
cd "$(dirname "$0")/.."
source ../.env
api="https://${KONNECT_REGION}.api.konghq.com"
id=$(curl -sf -H "Authorization: Bearer ${KONNECT_TOKEN}" "${api}/v1/ai-gateways?page%5Bsize%5D=100" \
  | jq -r '.data[] | select(.name=="acme-ai-gateway") | .id')
[ -n "$id" ] || { echo "nothing to delete"; exit 0; }
read -r -p "Delete acme-ai-gateway ($id) and everything in it? [y/N] " ok
[ "$ok" = "y" ] || { echo "kept"; exit 0; }
curl -sf -X DELETE -H "Authorization: Bearer ${KONNECT_TOKEN}" "${api}/v1/ai-gateways/${id}" -o /dev/null -w "deleted (%{http_code})\n"
