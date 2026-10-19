# YAGPDB

YAGPDB runs with PostgreSQL and Redis and is exposed through the external
`proxy` network.

## Configure and run

Review required bot tokens, database credentials, and volume mounts in
`compose.yaml`. Supply all credentials through local environment configuration
or Docker secrets, then start:

```sh
docker compose up -d
```

Keep bot tokens private and back up the database and persistent volumes.
