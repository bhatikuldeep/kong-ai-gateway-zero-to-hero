# Part 1, Setup. Four commands, the same in every part: up, test, down, clean.
SHELL := /bin/bash
# Run through mise when it's installed, so the pinned tool versions are used even if mise isn't activated.
RUN := $(shell command -v mise >/dev/null 2>&1 && echo "mise exec --")
COMPOSE := docker compose --env-file ../.env
# Stopping must not need the gateway's connection details (they may not exist yet).
COMPOSE_STOP := KONG_CLUSTER_CONTROL_PLANE=not-set $(COMPOSE)

.PHONY: help up test down clean
help:    ## list the commands
	@grep -hE '^[a-z]+:.*## ' $(firstword $(MAKEFILE_LIST)) | sed -E 's/:.*## / /' | awk '{t=$$1; $$1=""; printf "  make %-6s%s\n", t, $$0}'

up:      ## start everything: Acme's gateway in Konnect (shows the changes first), then the containers
	@$(RUN) scripts/up.sh

test:    ## check that everything works
	@$(RUN) scripts/test.sh

down:    ## stop the containers
	@$(COMPOSE_STOP) down

clean:   ## remove everything: containers, downloaded model and the gateway in Konnect
	-@$(COMPOSE_STOP) down -v
	@$(RUN) scripts/delete-gateway.sh
