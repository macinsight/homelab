# Forgejo

Forgejo is a self-hosted Git forge with a PostgreSQL database and persistent
application data.

## Configure and run

Replace the database password in `compose.yaml` with a secret environment
variable or Docker secret before deploying. Create the external `proxy` network,
then start the stack:

```sh
docker compose up -d
```

Back up both the `data` and `db` volumes before upgrades.
