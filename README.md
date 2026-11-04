# Kong AI Gateway, from first call to production

Runnable companion to the blog series at [kuldeepbhati.com](https://kuldeepbhati.com). Each episode is one use case on Kong AI Gateway 2.x with Konnect, a local data plane in Docker and a local model, so you can try it on a laptop in about 15 minutes and remove it again.

> A personal series. Views are my own; this is not official Kong documentation.

## What you need

- Docker (Docker Desktop on macOS or Windows with WSL; Docker Engine on Linux), about 2 GB free RAM
- A Konnect account with AI Gateway ([pricing and plans](https://konghq.com/pricing))
- [mise](https://mise.jdx.dev), which installs the pinned tools (`kongctl` 1.25.0, `jq` 1.8.2, `gitleaks` 8.30.1; checksums in `mise.lock`). The `make` commands use them through mise, so you don't need to activate it in your shell

## Start here: 000 Setup

```bash
cp .env.example .env          # add your KONNECT_TOKEN and region
mise install
cd setup
make up                       # start everything (the first run shows the Konnect changes and asks to confirm)
make test                     # check that everything works
```

Every episode uses the same four commands:

| Command | What it does |
|---|---|
| `make up` | Start everything. Safe to run again |
| `make test` | Check that everything works |
| `make down` | Stop the containers |
| `make clean` | Remove everything: containers, downloaded model and the gateway in Konnect |

If port 8000 is already used on your machine, set another one in `GATEWAY_PORT` in `.env`.

## Episodes

| Episode | Folder | Post |
|---|---|---|
| 000 Setup | [`setup/`](setup/) | coming soon |

The fictional company in every episode is **Acme**, an online retailer. Its people, teams and systems stay the same across the series.

## Troubleshooting

- **`make test` says there's no Kong gateway on port 8000:** run `make up`. If another program already uses port 8000, set `GATEWAY_PORT` in `.env` and run `make up` again.
- **The first answer takes a second or two:** the model is loading. Later answers take a few hundred milliseconds.
- **The gateway logs show `dynamic_pricing: ... ignored unknown field` notices:** they're harmless. AI Gateway 2.3 fetches Konnect's model price list every minute and skips fields it doesn't know yet.
- **`make up` asks you to type `yes`:** it shows what it will create or change in Konnect first. Later runs skip this when nothing changed.

## How the repository is built

- Every tool and image is pinned to an exact version: tools in `mise.toml` and `mise.lock`, container images by tag and digest, CI actions by commit. Versions change on purpose, in one commit, never by themselves.
- Each episode keeps its Konnect resources in its own kongctl namespace (`acme-<episode>`), so `make clean` in one episode removes only what that episode created.
- Ollama is the default model and needs no paid keys. Where an episode needs a paid provider, the post says so in a "Cost to run" line.
- Nothing from a real organisation is committed: `.env`, keys and certificates are git-ignored, and CI runs gitleaks.

## Licence

Code: [Apache-2.0](LICENSE). Text in the posts and READMEs: [CC BY 4.0](LICENSE-docs).
