# Dockerized Borgmatic backups

This stack performs encrypted, application-consistent backups to a Borg repository on a Hetzner Storage Box. It runs Borgmatic in a container, creates logical database exports through the local Docker socket, and archives persistent file data, exported volumes, encrypted Compose configuration, and the source checkout.

It intentionally excludes raw live database files. PostgreSQL, MariaDB, and MongoDB are backed up with logical dumps before Borg starts. File- and SQLite-backed volumes are briefly paused, exported to `/exports/current/volumes`, and resumed before Borg archives them.

## Prerequisites

- Docker Engine and Docker Compose plugin on the host.
- A Storage Box subaccount restricted to the Borg repository directory over SSH.
- The Storage Box SSH host key, obtained and verified out of band.
- An age identity able to decrypt the encrypted Borg environment file.
- SOPS available locally to create or update encrypted secrets.

The backup container mounts the Docker socket. Treat this repository, its image, and its hooks as host-admin code: Docker socket access is root-equivalent.

## Configure

1. Copy `.env.example` to `.env` and set `BACKUP_SOURCE_ROOT` to the absolute path of this checkout. The stack mounts the homelab repository read-only at `/stacks`.
2. Create `secrets/age.key` with the age private identity. Do not commit it.
3. Create `secrets/storagebox_ed25519` with the dedicated Storage Box SSH private key and set mode `0600`.
4. Create `secrets/known_hosts` containing the verified Storage Box host key.
5. Create and encrypt `secrets/borg.env.sops`:

   ```dotenv
   BORG_REPOSITORY=ssh://storagebox-user@storagebox-host:23/./borg/server-name
   BORG_PASSPHRASE=use-a-unique-long-random-passphrase
   ```

   ```sh
   sops --encrypt --age "$AGE_RECIPIENT" \
     secrets/borg.env > secrets/borg.env.sops
   rm secrets/borg.env
   ```

6. Build and initialize the repository once:

   ```sh
   docker compose build
   docker compose run --rm borgmatic sh -c '. /run/borgmatic/borg.env && /usr/local/bin/run-borg init --encryption=repokey-blake2 "$BORG_REPOSITORY"'
   ```

7. Start the scheduler:

   ```sh
   docker compose up -d
   ```

The default schedule is daily at 03:00 local time. Set `BACKUP_SCHEDULE` in `.env` to change it.

## Run and verify

Run a backup immediately:

```sh
docker compose exec borgmatic /usr/local/bin/run-backup
```

Check the repository weekly:

```sh
docker compose exec borgmatic sh -c '. /run/borgmatic/borg.env && /usr/local/bin/run-borg check "$BORG_REPOSITORY"'
```

The configured retention is 14 daily, 8 weekly, and 12 monthly archives. Borgmatic runs repository and archive checks on every scheduled backup; use a separate scheduled `borg check` for deeper cryptographic verification.

## Restore

Do not run restores from the scheduler container. On a fresh host, install Docker, restore this repository and persistent data from the Borg archive, decrypt the service configuration with the age identity, restore database dumps, create the external `proxy` network, then start Traefik and the application stacks.

Restore databases before their dependent services:

- PostgreSQL: Authentik, Forgejo, Immich, Keycloak, Paperless, Vikunja, YAGPDB
- MariaDB: Pyrodactyl
- MongoDB: Komodo

The service and volume lists in `hooks/dump-databases.sh` match the current Compose project and service names. After adding or renaming a stack, update that manifest and the corresponding exclusions in `borgmatic/config.yaml.template`, then test an immediate backup and a restore.
