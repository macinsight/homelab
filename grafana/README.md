# Grafana

Grafana provides dashboards with persistent state stored in the `data` volume.

## Run

Create the external `proxy` network if required by your deployment, then start
the stack:

```sh
docker compose up -d
```

Configure administrator credentials and data-source credentials through local
environment configuration or Docker secrets; do not add them to this repository.
