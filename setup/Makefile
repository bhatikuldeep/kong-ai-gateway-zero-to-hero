# 000 Setup. Run from this folder: make help
SHELL := /bin/bash
include ../.env
export
API := https://$(KONNECT_REGION).api.konghq.com
GATEWAY := acme-ai-gateway
COMPOSE := docker compose --env-file ../.env

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
	kongctl plan --mode apply -f konnect/ai-gateway.yaml --pat "$(KONNECT_TOKEN)" --base-url $(API) --output-file plan.json
	kongctl apply --plan plan.json --pat "$(KONNECT_TOKEN)" --base-url $(API)

endpoints:     ## write the gateway's data plane endpoints into ../.env
	@scripts/endpoints.sh

up: endpoints  ## start the data plane and Ollama, pull the model
	$(COMPOSE) up -d
	$(COMPOSE) exec ollama ollama pull $(LLM_MODEL)

test:          ## assert the setup works (no key -> 401, key -> answer from the local model)
	@scripts/test.sh

down:          ## stop containers; Konnect stays as it is
	$(COMPOSE) down

down-all:      ## remove everything: containers, model volume and the gateway in Konnect
	$(COMPOSE) down -v
	@scripts/delete-gateway.sh
