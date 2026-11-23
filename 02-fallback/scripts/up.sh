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

# The stand-in models and the vector store, on Part 1's Docker network
docker compose -f compose.yaml up -d --wait
# The embeddings model for semantic routing, in Part 1's Ollama (about 270 MB, once)
docker compose -p acme-aigw exec -T ollama ollama list </dev/null | grep -q '^nomic-embed-text' \
  || docker compose -p acme-aigw exec -T ollama ollama pull nomic-embed-text </dev/null

kongctl plan --mode apply -f konnect/ \
  --region "$KONNECT_REGION" --output-file plan.json
if [ "$(jq '.summary.total_changes' plan.json)" -gt 0 ]; then
  kongctl apply --plan plan.json --region "$KONNECT_REGION"
else
  echo "Konnect is up to date"
fi
rm -f plan.json

# Wait until the data plane has the new models (it polls Konnect for configuration)
url=http://127.0.0.1:${GATEWAY_PORT:-8000}/v1/chat/completions
for model in acme-chat-fallback acme-lb-semantic; do
  for _ in $(seq 1 30); do
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 30 "$url" -H 'content-type: application/json' \
      -H @<(printf "apikey: %s\n" "$SHOP_APP_KEY") \
      -d "{\"model\": \"$model\", \"messages\": [{\"role\": \"user\", \"content\": \"Where is my order?\"}]}")
    [ "$code" = 200 ] && break
    sleep 2
  done
  [ "$code" = 200 ] || { echo "The data plane hasn't picked up $model after 60 s (last status ${code}): check 'docker compose -p acme-aigw logs kong'"; exit 1; }
done
echo "Ready: run 'make test'"
