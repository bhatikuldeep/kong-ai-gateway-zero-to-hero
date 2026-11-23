#!/usr/bin/env bash
# make clean: remove only what Part 2 added (namespace acme-fallback). Part 1's gateway stays.
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source ../.env; set +a
export KONGCTL_DEFAULT_KONNECT_PAT="${KONNECT_TOKEN:-}"   # kongctl reads the token from here, never from the command line
# The stand-in models and the vector store (no data worth keeping), and the embeddings model in Ollama
docker compose -f compose.yaml down -v --remove-orphans
docker compose -p acme-aigw exec -T ollama ollama rm nomic-embed-text </dev/null >/dev/null 2>&1 || true
[ -n "${AI_GATEWAY_ID:-}" ] || { echo "nothing to remove in Konnect (no gateway id in .env)"; exit 0; }
kongctl plan --mode delete -f konnect/ \
  --region "$KONNECT_REGION" --output-file plan.json
if [ "$(jq '.summary.total_changes' plan.json)" -gt 0 ]; then
  kongctl delete --plan plan.json --region "$KONNECT_REGION"
else
  echo "nothing to remove"
fi
rm -f plan.json
