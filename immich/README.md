# Immich

Immich provides photo and video management with Redis, PostgreSQL, and a
machine-learning service.

## Configure

Create a local `.env` containing `UPLOAD_LOCATION`, `DB_DATA_LOCATION`,
`DB_PASSWORD`, `DB_USERNAME`, `DB_DATABASE_NAME`, and `IMMICH_VERSION`.
Keep the database password and local storage paths private.

Start the stack with:

```sh
docker compose up -d
```

Back up the upload and PostgreSQL locations before upgrades.
