# Traefik

Traefik is the reverse proxy for stacks connected to the external `proxy`
network. It persists ACME certificate storage and access logs.

## Run

Create the network before starting Traefik:

```sh
docker network create proxy
docker compose up -d
```

Protect certificate storage and any DNS-provider credentials used for ACME.
Review router labels in each application stack before exposing it publicly.

## Dashboard authentication

The dashboard is available at
`https://proxy.macinsight.net/dashboard/` and is protected through
`https://auth.macinsight.net`. Configure an Authentik Proxy Provider with
`https://proxy.macinsight.net` as its external host before accessing it.
