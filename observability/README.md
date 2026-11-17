# Optional: Acme's AI traffic in Grafana

Metrics, traces and logs for every part of the series, in one Grafana:

| What | How it gets there |
|---|---|
| Metrics | A global **Prometheus** policy (`ai_metrics: true`) on the AI Gateway; Prometheus scrapes the data plane's Status API (`kong:8100`, inside the Docker network) |
| Traces | A global **OpenTelemetry** policy sends one trace per request to the Collector, which writes to Tempo |
| Traffic logs | The same policy sends one structured access log line per request; the Collector writes it to Loki (`{service_name="kong-ai-gateway"}`) |
| Container logs | Grafana Alloy reads Part 1's containers from Docker and writes to Loki (`{container="kong"}`); the data plane's warnings land here |
| Dashboard | [Kong AI Gateway Dashboard (24329)](https://grafana.com/grafana/dashboards/24329-kong-ai-gateway-dashboard/), downloaded by `make up` (revision 1, checksum verified) |

Run the commands in this folder (`observability/`), with Part 1 running:

```bash
make up      # starts the containers, then shows the two policies for Konnect and asks you to confirm
make test    # sends 3 requests and checks they arrive as metrics, traces, traffic logs and container logs
```

Then open http://127.0.0.1:3000 (user `admin`, password `GRAFANA_ADMIN_PASSWORD` in `../.env`; `make up` creates it). The dashboard opens with its MCP panels; the LLM panels are further down.

| Command | What it does |
|---|---|
| `make up` | Start the stack and add the two policies (namespace `acme-observability`). Safe to run again |
| `make test` | Check that metrics, traces and both kinds of logs arrive |
| `make down` | Stop the containers; their data is kept |
| `make clean` | Remove the containers, their data and the two policies in Konnect |

Notes:

- Part 1's data plane must have the Status API (`KONG_STATUS_LISTEN`). If you ran Part 1 before this folder existed, run `make up` in `../01-setup` once.
- Loki's default limit is 128 structured metadata entries per line; a Kong access log line has about 133, so `loki/loki.yaml` raises it. Without that, Loki rejects every line and only the Collector's log shows it.
- Alloy reads the Docker socket read-only and only containers of the `acme-aigw` compose project.
- Everything listens on 127.0.0.1 or inside the Docker network. Grafana keeps its admin login.
