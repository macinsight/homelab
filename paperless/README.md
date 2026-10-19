# Paperless-ngx

Paperless-ngx consumes and archives documents using PostgreSQL, Redis,
Gotenberg, and Tika.

## Configure

Create a local `.env` with the Paperless application key, URL settings, and OIDC
credentials. Keep `PAPERLESS_SECRET_KEY` and all OAuth client secrets out of
version control.

Start the stack:

```sh
docker compose up -d
```

Back up the `data`, `media`, `export`, and `pgdata` volumes before upgrades.