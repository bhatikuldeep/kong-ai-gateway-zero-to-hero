#!/usr/bin/env bash
# make clean: remove the two policies this folder added in Konnect (the containers are removed by the Makefile)
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source ../.env; set +a
export KONGCTL_DEFAULT_KONNECT_PAT="${KONNECT_TOKEN:-}"   # kongctl reads the token from here, never from the command line
kongctl plan --mode delete -f konnect/policies.yaml --region "$KONNECT_REGION" --output-file plan.json
if [ "$(jq '.summary.total_changes' plan.json)" -gt 0 ]; then
  kongctl delete --plan plan.json --region "$KONNECT_REGION"
else
  echo "Nothing to remove in Konnect"
fi
rm -f plan.json grafana/dashboards/kong-ai-gateway.json
