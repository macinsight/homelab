# Dockerized Borgmatic backups

This stack performs encrypted, application-consistent backups to a Borg repository on a Hetzner Storage Box. It runs Borgmatic in a container, creates logical database exports through the local Docker socket, and archives persistent file data, exported volumes, encrypted Compose configuration, and the source checkout.

It intentionally excludes raw live database files. PostgreSQL, MariaDB, and MongoDB are backed up with logical dumps before Borg starts. File- and SQLite-backed volumes are briefly paused, exported to `/exports/current/volumes`, and resumed before Borg archives them.

## Full-volume local relay backup

`backup-compose-volumes.sh` is a host-side alternative for a full, cold backup
of every Compose project's named volumes. It:

1. discovers Compose files below `BACKUP_SOURCE_ROOT`;
2. records the services that are running and the volumes attached to every
   project container;
3. stops only projects with running services, exports every discovered named
   volume to a tar file, and creates an archive in a **local** Borg repository;
4. restarts exactly the services that were running before the backup; and
5. transfers only that new archive to the Hetzner Storage Box using Borg 2.

The script does not remove volumes or delete local archives. A remote-transfer
failure leaves the local archive available and restores the recorded services.

1. Install Borg 2 and Docker Compose on the host. The account running the
   script must use Docker and needs an SSH key and verified `known_hosts` entry
   for the Storage Box.
2. Initialize the local and Storage Box repositories with Borg 2 before the
   first run. Repositories using different passphrases need
   `BORG_OTHER_REPO_PASSPHRASE`.
3. Copy `compose-volume-backup.env.example` to
   `compose-volume-backup.env`, set its values, and restrict it to the backup
   account (`chmod 0600 borgmatic/compose-volume-backup.env`).
4. Run it from a host account that can read and write the local repository:

   ```sh
   ./borgmatic/backup-compose-volumes.sh
   ```

The volume exports are tar files under `volumes/` in the Borg archive. To
restore one, extract that file, then use a temporary container with the target
volume mounted to unpack it. Test this process before relying on a backup.

## Restoring from the Storage Box

`restore-compose-volumes.sh` retrieves an archive directly from the Storage
Box, validates its volume exports, and restores each volume. It clones the
Compose repository when `COMPOSE_CHECKOUT` does not exist, or updates a clean
checkout to the configured `COMPOSE_REF` before any volume is replaced.

List eligible archives:

```sh
./borgmatic/restore-compose-volumes.sh --list
```

Before restoring, stop and remove every container that uses the target
volumes. Then restore the selected archive. Existing volumes are protected by
default; `--replace-existing` is required to delete and recreate them:

```sh
./borgmatic/restore-compose-volumes.sh \
  --archive compose-volumes-host-YYYYMMDDTHHMMSSZ \
  --replace-existing
```

The script does not start services by default because the checkout may need
private environment files or secrets restored first. After restoring those,
pass `--start` to start every discovered Compose project, or start selected
projects manually with `docker compose up -d`.

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
