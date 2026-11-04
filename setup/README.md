# 000 Setup

Creates Acme's AI Gateway in Konnect and runs a self-hosted data plane for it in Docker, with Ollama serving the model next to the gateway.

Run these commands in this folder (`setup/`), after the one-time steps in the [main README](../README.md#quick-start):

| Command | What it does |
|---|---|
| `make up` | Start everything. Safe to run again |
| `make test` | Check that everything works |
| `make down` | Stop the containers |
| `make clean` | Remove everything: containers, downloaded model and the gateway in Konnect |

## What `make up` creates

In Konnect (kongctl namespace `acme`):
- **AI Gateway** `acme-ai-gateway`, with this data plane's certificate;
- **model provider** `setup-ollama` (Ollama, next to the gateway);
- **auth strategy** `setup-key-auth` (API keys in the `apikey` header);
- **model** `acme-chat` at `/v1`, served by `qwen2.5:0.5b`;
- **consumer** `shop-app` with its key (stored as `SHOP_APP_KEY` in `.env`).

In Docker (Compose project `acme-aigw`):
- `kong`: the Kong AI Gateway 2.3 data plane, on `127.0.0.1:8000` (`GATEWAY_PORT` in `.env`);
- `ollama`: the model server, reachable only by the gateway.

## Files

| File | What it is |
|---|---|
| `konnect/ai-gateway.yaml` | The Konnect resources above, applied with kongctl |
| `compose.yaml` | The two containers, pinned by digest |
| `scripts/up.sh` | The steps behind `make up`, in order, with comments |
| `scripts/test.sh` | The checks behind `make test` |
| `scripts/delete-gateway.sh` | Removes the gateway in Konnect (asks first) |
