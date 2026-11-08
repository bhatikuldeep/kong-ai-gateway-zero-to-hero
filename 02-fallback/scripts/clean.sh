#!/usr/bin/env bash
# make clean: remove only what Part 2 added (namespace acme-fallback). Part 1's gateway stays.
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source ../.env; set +a
[ -n "${AI_GATEWAY_ID:-}" ] || { echo "nothing to remove (no gateway id in .env)"; exit 0; }
kongctl plan --mode delete -f konnect/ai-gateway.yaml \
  --pat "$KONNECT_TOKEN" --region "$KONNECT_REGION" --output-file plan.json
if [ "$(jq '.summary.total_changes' plan.json)" -gt 0 ]; then
  kongctl delete --plan plan.json --pat "$KONNECT_TOKEN" --region "$KONNECT_REGION"
else
  echo "nothing to remove"
fi
rm -f plan.json
