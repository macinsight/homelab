# TSDProxy configuration

`tsdproxy.yaml` configures how TSDProxy discovers and publishes Docker services
through Tailscale.

Keep Tailscale authentication keys and any private tailnet details outside this
file. Validate changes against the TSDProxy documentation before redeploying,
then restart the service from the parent directory:

```sh
docker compose up -d
```
