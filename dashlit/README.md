# Dashlit

Dashlit provides a dashboard service exposed through the external `proxy`
network.

## Configure

Create a local environment file with the initial administrator password, JWT
secret, and OIDC settings required by `compose.yaml`. In particular, keep
`INITIAL_ADMIN_PASSWORD`, `JWT_SECRET`, and `OIDC_CLIENT_SECRET` out of version
control.

Start it with:

```sh
docker compose up -d
```
