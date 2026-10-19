# Komodo

Komodo manages container deployments using a MongoDB database and a Periphery
agent. It can execute operations against the host, so treat access to this stack
as administrative access.

## Configure

Copy `compose.env` to a private local configuration location and replace all
database, administrator, webhook, JWT, and OIDC credentials. Do not commit the
result. Configure the external `proxy` network and required key files before
starting.

```sh
docker compose --env-file /path/to/compose.env up -d
```

Back up MongoDB data, Komodo keys, and its configured backup location.
