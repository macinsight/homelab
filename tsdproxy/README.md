# TSDProxy

TSDProxy publishes Docker services through Tailscale. Its runtime behavior is
configured by `config/tsdproxy.yaml`.

## Run

Review the configuration and required Tailscale authentication settings, then
start the stack:

```sh
docker compose up -d
```

Use an ephemeral or tightly scoped Tailscale auth key supplied at runtime; do
not commit it.
