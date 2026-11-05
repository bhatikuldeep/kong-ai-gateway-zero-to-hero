# Hands-on Kong AI Gateway

## Overview

Runnable code for a series of curated, hands-on blog posts at [kuldeepbhati.com](https://kuldeepbhati.com). Each part is one use case on Kong AI Gateway 2.x: Konnect as the control plane, a self-hosted data plane in Docker, and an open model served by Ollama next to the gateway. The examples follow **Acme**, a fictional online retailer.

| Part | Folder | Post |
|---|---|---|
| 1. Setup | [`01-setup/`](01-setup/) | [Your first governed LLM endpoint with Kong AI Gateway and Konnect](https://kuldeepbhati.com/posts/part-1-governed-llm-endpoint-kong-ai-gateway-konnect/) |

> A personal series. Views are my own; this is not official Kong documentation.

## Prerequisites

- Docker (Docker Desktop on macOS or Windows with WSL; Docker Engine on Linux), about 2 GB free RAM
- A Konnect account with AI Gateway ([pricing and plans](https://konghq.com/pricing))
- [mise](https://mise.jdx.dev), which installs the pinned tools (`kongctl`, `jq`, `gitleaks`)

## Getting started

1. In the repository root, configure your Konnect access and install the tools:

   ```bash
   cp .env.example .env    # then set KONNECT_TOKEN and KONNECT_REGION
   mise install
   ```

2. Run part 1, Setup. It creates the AI Gateway that every later part builds on:

   ```bash
   cd 01-setup
   make up      # shows the Konnect changes and asks you to confirm
   make test    # checks that everything works
   ```

Every part has its own folder (`01-setup/`, then `02-<topic>/` and so on) with the same four commands:

| Command | What it does |
|---|---|
| `make up` | Start everything. Safe to run again |
| `make test` | Check that everything works |
| `make down` | Stop the containers |
| `make clean` | Remove everything: containers, downloaded model and the gateway in Konnect |

## Troubleshooting

- **`make test` finds no Kong gateway:** run `make up`. If port 8000 is already in use, set `GATEWAY_PORT` in `.env` and run `make up` again.
- **The first answer takes a second or two:** the model is loading. Later answers take a few hundred milliseconds.

## Licence

Code: [Apache-2.0](LICENSE). Text in the posts and READMEs: [CC BY 4.0](LICENSE-docs).
