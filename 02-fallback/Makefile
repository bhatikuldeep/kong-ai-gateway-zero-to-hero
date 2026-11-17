# Part 2, Fallback. Four commands, the same in every part: up, test, down, clean.
SHELL := /bin/bash
RUN := $(shell command -v mise >/dev/null 2>&1 && echo "mise exec --")

.PHONY: help up test down clean
help:    ## list the commands
	@grep -hE '^[a-z]+:.*## ' $(firstword $(MAKEFILE_LIST)) | sed -E 's/:.*## / /' | awk '{t=$$1; $$1=""; printf "  make %-6s%s\n", t, $$0}'

up:      ## add the Claude provider and the fallback model to Acme's gateway (shows the changes first)
	@$(RUN) scripts/up.sh

test:    ## check failover: Ollama answers, stop Ollama, Claude answers, start Ollama, Ollama answers again
	@$(RUN) scripts/test.sh

down:    ## nothing to stop: this part uses Part 1's containers
	@echo "Part 2 adds no containers. To stop them: cd ../01-setup && make down"

clean:   ## remove what this part added in Konnect (Part 1's gateway stays)
	@$(RUN) scripts/clean.sh
