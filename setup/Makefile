# 000 Setup. Run from this folder: make help
SHELL := /bin/bash
include ../.env
export
API := https://$(KONNECT_REGION).api.konghq.com
GATEWAY := acme-ai-gateway
COMPOSE := docker compose --env-file ../.env
# Stopping must work even before `make endpoints` has run (for example after a failed apply).
COMPOSE_STOP := KONG_CLUSTER_CONTROL_PLANE=$${KONG_CLUSTER_CONTROL_PLANE:-not-set} $(COMPOSE)

.PHONY: help check certs key apply endpoints up test down down-all
help:          ## list targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | sed 's/:.*## /\t/'

check:         ## tools, Docker and .env are ready
	@command -v kongctl >/dev/null || { echo "kongctl missing: run 'mise install'"; exit 1; }
	@docker info >/dev/null 2>&1 || { echo "Docker is not running"; exit 1; }
	@test -n "$(KONNECT_TOKEN)" || { echo "Set KONNECT_TOKEN in ../.env"; exit 1; }
	@echo "ok"

certs:         ## data plane certificate (RSA; Konnect rejects some EC encodings)
	@mkdir -p certs
	@test -f certs/tls.key || openssl req -new -x509 -nodes -newkey rsa:2048 -days 365 \
	  -subj "/CN=acme-dp" -keyout certs/tls.key -out certs/tls.crt 2>/dev/null
	@echo "certs/tls.crt ready"

key:           ## generate the shop app's API key into ../.env (once)
	@grep -q '^SHOP_APP_KEY=.\+' ../.env || sed -i.bak "s/^SHOP_APP_KEY=.*/SHOP_APP_KEY=$$(openssl rand -hex 16)/" ../.env && rm -f ../.env.bak
	@echo "SHOP_APP_KEY set in ../.env"

apply: check certs key   ## create or update Acme's AI Gateway in Konnect (shows the plan first)
	@# Re-read ../.env here: `make key` may have just written SHOP_APP_KEY, after make loaded the file.
	@# --base-dir: !file may read only inside setup/ (the certificate is in setup/certs)
	@set -a; . ../.env; set +a; \
	  kongctl plan --mode apply -f konnect/ai-gateway.yaml --base-dir . --pat "$$KONNECT_TOKEN" --region "$$KONNECT_REGION" --output-file plan.json && \
	  kongctl apply --plan plan.json --pat "$$KONNECT_TOKEN" --region "$$KONNECT_REGION"; rc=$$?; rm -f plan.json; exit $$rc

endpoints:     ## write the gateway's data plane endpoints into ../.env
	@scripts/endpoints.sh

up: endpoints  ## start the data plane and Ollama (Ollama pulls and tunes the model on first start)
	$(COMPOSE) up -d --wait

test:          ## assert the setup works (no key -> 401, key -> answer from the local model)
	@scripts/test.sh

down:          ## stop containers; Konnect stays as it is
	$(COMPOSE_STOP) down

down-all:      ## remove everything: containers, model volume and the gateway in Konnect
	-$(COMPOSE_STOP) down -v
	@scripts/delete-gateway.sh
