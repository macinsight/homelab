# Technitium DNS Server

Technitium provides DNS and related network services with persistent server
configuration.

## Run

Review the published ports, volume mounts, and restart policy in `compose.yaml`,
then start the stack:

```sh
docker compose up -d
```

Restrict DNS administration access and back up the server configuration before
upgrades.
