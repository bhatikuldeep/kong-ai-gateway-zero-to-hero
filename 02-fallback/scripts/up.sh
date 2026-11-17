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
export KONGCTL_DEFAULT_KONNECT_PAT="${KONNECT_TOKEN:-}"   # kongctl reads the token from here, never from the command line

# Part 1 must be running: this part adds to its gateway and uses its containers
[ -n "${AI_GATEWAY_ID:-}" ] || { echo "Run Part 1 first: cd ../01-setup && make up"; exit 1; }
docker compose -p acme-aigw ps --status running --services 2>/dev/null | grep -qx kong \
  || { echo "Part 1's containers aren't running: cd ../01-setup && make up"; exit 1; }
[ -n "${ANTHROPIC_API_KEY:-}" ] || { echo "Set ANTHROPIC_API_KEY in .env (a Claude API key from the Claude Console)"; exit 1; }
[ -n "${CLAUDE_MODEL:-}" ] || { echo "Set CLAUDE_MODEL in .env"; exit 1; }

kongctl plan --mode apply -f konnect/ai-gateway.yaml \
  --region "$KONNECT_REGION" --output-file plan.json
if [ "$(jq '.summary.total_changes' plan.json)" -gt 0 ]; then
  kongctl apply --plan plan.json --region "$KONNECT_REGION"
else
  echo "Konnect is up to date"
fi
rm -f plan.json

# Wait until the data plane has the new model (it polls Konnect for configuration)
url=http://127.0.0.1:${GATEWAY_PORT:-8000}/v1/chat/completions
body='{"model": "acme-chat-fallback", "messages": [{"role": "user", "content": "ping"}]}'
for _ in $(seq 1 30); do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 30 "$url" -H 'content-type: application/json' \
    -H @<(printf "apikey: %s\n" "$SHOP_APP_KEY") -d "$body")
  [ "$code" = 200 ] && { echo "Ready: run 'make test'"; exit 0; }
  sleep 2
done
echo "The data plane hasn't picked up the change after 60 s (last status ${code}): check 'docker compose -p acme-aigw logs kong'"
exit 1
