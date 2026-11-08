#!/usr/bin/env bash
# make up: add Part 2's resources to Acme's gateway. Safe to run again.
set -euo pipefail
cd "$(dirname "$0")/.."
env_file=../.env

for tool in kongctl jq; do
  command -v "$tool" >/dev/null || { echo "$tool not found: run 'mise install' in the repository root"; exit 1; }
done
# Add settings that are new in .env.example since you created .env, with their defaults
while IFS= read -r line; do
  key=${line%%=*}
  grep -q "^${key}=" "$env_file" || { echo "$line" >> "$env_file"; echo "Added ${key} to .env (new setting)"; }
done < <(grep -E '^[A-Z_]+=' ../.env.example)
set -a; source "$env_file"; set +a

# Part 1 must be running: this part adds to its gateway and uses its containers
[ -n "${AI_GATEWAY_ID:-}" ] || { echo "Run Part 1 first: cd ../01-setup && make up"; exit 1; }
docker compose -p acme-aigw ps --status running --services 2>/dev/null | grep -qx kong \
  || { echo "Part 1's containers aren't running: cd ../01-setup && make up"; exit 1; }
[ -n "${ANTHROPIC_API_KEY:-}" ] || { echo "Set ANTHROPIC_API_KEY in .env (a Claude API key from the Claude Console)"; exit 1; }
[ -n "${CLAUDE_MODEL:-}" ] || { echo "Set CLAUDE_MODEL in .env"; exit 1; }

kongctl plan --mode apply -f konnect/ai-gateway.yaml \
  --pat "$KONNECT_TOKEN" --region "$KONNECT_REGION" --output-file plan.json
if [ "$(jq '.summary.total_changes' plan.json)" -gt 0 ]; then
  kongctl apply --plan plan.json --pat "$KONNECT_TOKEN" --region "$KONNECT_REGION"
else
  echo "Konnect is up to date"
fi
rm -f plan.json
echo "Ready: run 'make test' (the data plane picks up the change within a few seconds)"
