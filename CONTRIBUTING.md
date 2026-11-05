# Contributing

Issues are welcome: a step that didn't work, a version that changed, a question about a part.
Please include your OS, Docker version and the output of `make test`. Never paste your `.env`,
tokens or certificates.

## How the repository is built

- Every tool and image is pinned to an exact version: tools in `mise.toml` and `mise.lock` (with checksums), container images by tag and digest, CI actions by commit. Versions change on purpose, in one commit.
- Each part keeps its Konnect resources in its own kongctl namespace (`acme-<part>`), so later parts can be removed one at a time. `make clean` in `01-setup/` removes the whole gateway.
- Ollama serves the default model and needs no paid keys. Where a part needs a paid provider, the post says so in a "Cost to run" line.
- Nothing from a real organisation is committed: `.env`, keys and certificates are git-ignored, and CI runs gitleaks.
