# 000 Setup. Four commands, the same in every episode: up, test, down, clean.
SHELL := /bin/bash
COMPOSE := docker compose --env-file ../.env
# Stopping must not need the gateway's connection details (they may not exist yet).
COMPOSE_STOP := KONG_CLUSTER_CONTROL_PLANE=not-set $(COMPOSE)

.PHONY: help up test down clean
help:    ## list the commands
	@grep -hE '^[a-z]+:.*## ' $(firstword $(MAKEFILE_LIST)) | sed -E 's/:.*## / /' | awk '{t=$$1; $$1=""; printf "  make %-6s%s\n", t, $$0}'

up:      ## start everything: Acme's gateway in Konnect (shows the changes first), then the containers
	@scripts/up.sh

test:    ## check that everything works
	@scripts/test.sh

down:    ## stop the containers
	@$(COMPOSE_STOP) down

clean:   ## remove everything: containers, downloaded model and the gateway in Konnect
	-@$(COMPOSE_STOP) down -v
	@scripts/delete-gateway.sh
