# Authentik

Identity provider backed by PostgreSQL. The stack exposes Authentik through the
external `proxy` Docker network.

## Configure

Create a local `.env` file containing `PG_PASS` and `AUTHENTIK_SECRET_KEY`.
Optional variables include `PG_DB` and `PG_USER`; their defaults are defined in
`compose.yaml`.

Start the stack with:

```sh
docker compose up -d
```

Keep `.env`, database volumes, and uploaded application data private.
