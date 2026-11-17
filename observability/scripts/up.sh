#!/usr/bin/env bash
# make up: the optional Grafana stack next to Part 1. Safe to run again.
set -euo pipefail
cd "$(dirname "$0")/.."
env_file=../.env
set_env() { sed -i.bak "s#^$1=.*#$1=$2#" "$env_file" && rm -f "$env_file.bak"; }

for tool in kongctl jq curl; do
  command -v "$tool" >/dev/null || { echo "$tool not found: run 'mise install' in the repository root"; exit 1; }
done
# Add settings that are new in .env.example since you created .env, with their defaults
while IFS= read -r line; do
  key=${line%%=*}
  grep -q "^${key}=" "$env_file" || { echo "$line" >> "$env_file"; echo "Added ${key} to .env (new setting)"; }
done < <(grep -E '^[A-Z_]+=' ../.env.example)
set -a; source "$env_file"; set +a
export KONGCTL_DEFAULT_KONNECT_PAT="${KONNECT_TOKEN:-}"   # kongctl reads the token from here, never from the command line

# Part 1 must be running, with the Status API (port 8100) that Prometheus scrapes
[ -n "${AI_GATEWAY_ID:-}" ] || { echo "Run Part 1 first: cd ../01-setup && make up"; exit 1; }
docker compose -p acme-aigw ps --status running --services 2>/dev/null | grep -qx kong \
  || { echo "Part 1's containers aren't running: cd ../01-setup && make up"; exit 1; }
docker inspect acme-aigw-kong-1 --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -q '^KONG_STATUS_LISTEN=' \
  || { echo "Part 1's data plane predates the Grafana stack: run 'make up' in ../01-setup once to update it"; exit 1; }

# Grafana admin password (created once, kept in .env)
[ -n "${GRAFANA_ADMIN_PASSWORD:-}" ] || { set_env GRAFANA_ADMIN_PASSWORD "$(openssl rand -hex 12)"; set -a; source "$env_file"; set +a; }

# Kong's official AI Gateway dashboard, revision 1, from grafana.com (checked, not stored in this repository)
mkdir -p grafana/dashboards
dash=grafana/dashboards/kong-ai-gateway.json
if [ ! -s "$dash" ]; then
  curl -sfL https://grafana.com/api/dashboards/24329/revisions/1/download -o "$dash.tmp"
  echo "1173a9fa599b9f7312f6f476b26e53b873cbb3bd519ffeebff28410367ac480a  $dash.tmp" | shasum -a 256 -c --quiet \
    || { echo "The dashboard download changed; check https://grafana.com/grafana/dashboards/24329"; exit 1; }
  jq 'del(.__inputs, .__requires) | .id = null' "$dash.tmp" > "$dash" && rm -f "$dash.tmp"
fi

docker compose --env-file "$env_file" up -d --wait

kongctl plan --mode apply -f konnect/policies.yaml --region "$KONNECT_REGION" --output-file plan.json
if [ "$(jq '.summary.total_changes' plan.json)" -gt 0 ]; then
  kongctl apply --plan plan.json --region "$KONNECT_REGION"
else
  echo "Konnect is up to date"
fi
rm -f plan.json
echo "Ready: run 'make test', then open http://127.0.0.1:${GRAFANA_PORT:-3000} (user admin, password GRAFANA_ADMIN_PASSWORD in .env)"
