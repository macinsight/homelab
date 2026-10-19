# Vikunja

Vikunja is a task-management service backed by PostgreSQL with persistent file
storage.

## Configure and run

Replace the database password in `compose.yaml` with a secret environment
variable or Docker secret before deployment. Then start the stack:

```sh
docker compose up -d
```

Back up the `db` and `files` volumes before upgrades.
