# Part 2, Load balancing and failover. Four commands, the same in every part: up, test, down, clean.
SHELL := /bin/bash
RUN := $(shell command -v mise >/dev/null 2>&1 && echo "mise exec --")

.PHONY: help up test down clean
help:    ## list the commands
	@grep -hE '^[a-z]+:.*## ' $(firstword $(MAKEFILE_LIST)) | sed -E 's/:.*## / /' | awk '{t=$$1; $$1=""; printf "  make %-6s%s\n", t, $$0}'

up:      ## start the stand-in models, add Claude and the load balancing models to Acme's gateway (shows the changes first)
	@$(RUN) scripts/up.sh

test:    ## check failover to Claude, then each load balancing strategy
	@$(RUN) scripts/test.sh

down:    ## stop this part's containers (stand-in models, vector store); Part 1 keeps running
	@docker compose -f compose.yaml down

clean:   ## remove this part's containers and what it added in Konnect (Part 1's gateway stays)
	@$(RUN) scripts/clean.sh
