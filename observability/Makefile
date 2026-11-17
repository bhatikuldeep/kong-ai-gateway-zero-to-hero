# Optional Grafana stack. Four commands, the same as every part: up, test, down, clean.
SHELL := /bin/bash
RUN := $(shell command -v mise >/dev/null 2>&1 && echo "mise exec --")
COMPOSE := GRAFANA_ADMIN_PASSWORD=not-set docker compose --env-file ../.env

.PHONY: help up test down clean
help:    ## list the commands
	@grep -hE '^[a-z]+:.*## ' $(firstword $(MAKEFILE_LIST)) | sed -E 's/:.*## / /' | awk '{t=$$1; $$1=""; printf "  make %-6s%s\n", t, $$0}'

up:      ## start Prometheus, Loki, Tempo, the Collector and Grafana, and add the metrics and tracing policies (shows the changes first)
	@$(RUN) scripts/up.sh

test:    ## send a few requests and check they arrive as metrics, traces and logs
	@$(RUN) scripts/test.sh

down:    ## stop the containers (data is kept)
	@$(COMPOSE) down

clean:   ## remove the containers, their data and the two policies in Konnect
	-@$(COMPOSE) down -v
	@$(RUN) scripts/clean.sh
