# Part 2: LLM load balancing and failover

Post: [LLM load balancing and failover with Kong AI Gateway](https://kuldeepbhati.com/posts/llm-fallback-kong-ai-gateway/)

Run the commands in this folder (`02-fallback/`), with Part 1 running and `ANTHROPIC_API_KEY` set in `../.env`:

```bash
make up      # starts two containers, shows the Konnect changes and asks you to confirm
make test    # failover to Claude, then every load balancing strategy
```

## What it adds

| Where | What |
|---|---|
| Konnect, namespace `acme-fallback` | `acme-chat-fallback` (Ollama first, Claude when Ollama fails), a stand-in provider and one AI Model per strategy (`acme-lb-*`). All on Part 1's endpoint, `/v1`, picked by the `model` the app sends |
| Docker, project `acme-aigw-lb` | `mock-llm`: stand-in models ([`../mocks/llm`](../mocks/llm/nginx.conf)) that answer `answered by <target>` and can be switched to failing. `vectors`: Redis Stack, the vector store for semantic routing |
| Part 1's Ollama | `nomic-embed-text`, the embeddings model for semantic routing (about 270 MB) |

| Model | Strategy | What `make test` checks |
|---|---|---|
| `acme-lb-priority` | priority, failover on errors, timeouts, 429 and 5xx, circuit breaker | the standby answers while the primary fails; the primary takes the traffic back after `fail_timeout` |
| `acme-lb-no-retry` | the same without `non_idempotent` | the primary's 503 reaches the app |
| `acme-lb-no-breaker` | the same without `max_fails` | every request still tries the failing primary first |
| `acme-lb-canary` | weighted round-robin, 90/10 | the candidate gets about 10% |
| `acme-lb-sticky` | consistent hashing on `X-Acme-User` | one user always reaches the same target |
| `acme-lb-fastest` | lowest latency (end to end) | the faster target takes most requests |
| `acme-lb-tokens` | lowest usage (total tokens) | the target that used fewer tokens takes most requests |
| `acme-lb-least-conn` | least connections | reported, not counted: on AI Gateway 2.3.2 it split traffic evenly |
| `acme-lb-semantic` | semantic routing | order questions reach `sem-orders`, code questions reach `sem-code` |

## Try it yourself

Send ten requests and see who answered:

```bash
source ../.env
for i in $(seq 10); do
  curl -s -o /dev/null -D - \
    http://127.0.0.1:${GATEWAY_PORT:-8000}/v1/chat/completions \
    -H 'content-type: application/json' -H "apikey: $SHOP_APP_KEY" \
    -d '{"model": "acme-lb-priority",
         "messages": [{"role": "user", "content": "Hello"}]}' \
    | grep -i '^x-kong-llm-model'
done
```

Make a stand-in model fail (503) and recover (each command prints how many requests that target has received):

```bash
docker compose exec mock-llm wget -qO- http://127.0.0.1:8081/down/prio-primary
docker compose exec mock-llm wget -qO- http://127.0.0.1:8081/up/prio-primary
```

## Clean up

| Command | What it does |
|---|---|
| `make down` | Stop this part's two containers. Part 1 keeps running |
| `make clean` | Remove the two containers, the embeddings model and everything this part added in Konnect. Part 1's gateway stays |

Stop this part before Part 1: Part 1's `make down` can't remove its Docker network while these containers use it (`Resource is still in use`).

## Troubleshooting

- **Semantic routing returns 503 or 500 on every request.** The data plane writes the target descriptions to the vector store when it loads the configuration. If the store was empty or unreachable then, restart the data plane: `docker compose -p acme-aigw restart kong`. The store is on a volume, so `make down` and `make up` keep it.
- **A model fails for some requests right after a container restart.** A worker process can cache that a stopped container's name didn't resolve; it recovers within seconds.
