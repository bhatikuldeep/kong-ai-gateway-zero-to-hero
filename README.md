# Kong AI Gateway, from first call to production

Runnable companion to the blog series at [kuldeepbhati.com](https://kuldeepbhati.com). Each episode is one use case on Kong AI Gateway 2.x with Konnect, a local data plane in Docker and a local model, so you can try it on a laptop in about 15 minutes and remove it again.

> A personal series. Views are my own; this is not official Kong documentation.

## What you need

- Docker (Docker Desktop on macOS or Windows with WSL; Docker Engine on Linux), about 4 GB free RAM for the local model
- A Konnect account with AI Gateway ([pricing and plans](https://konghq.com/pricing))
- [mise](https://mise.jdx.dev) for the pinned tools (`kongctl` 1.25.0, `jq` 1.8.2, `gitleaks` 8.30.1; checksums in `mise.lock`), or install those versions yourself

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
| 000 Setup | `setup/` | coming soon |

The fictional company in every episode is **Acme**, an online retailer. Its people, teams and systems stay the same across the series.

## Rules every episode follows

- Every tool and image is pinned to an exact version: tools in `mise.toml` and `mise.lock`, container images by tag and digest, CI actions by commit. Versions are bumped on purpose, in one change, never left floating.

- Each episode adds its own resources to Acme's gateway with names prefixed by its id (`llm02-...`), and `make down` removes only those. Episodes never use `kongctl sync`, which would delete other episodes' resources.
- Ollama is the default model and needs no paid keys. Where an episode needs a paid provider, the post says so in a "Cost to run" line.
- Nothing from a real organisation is committed: `.env`, keys and certificates are git-ignored, and CI runs gitleaks.

## Licence

Code: [Apache-2.0](LICENSE). Text in the posts and READMEs: [CC BY 4.0](LICENSE-docs).
