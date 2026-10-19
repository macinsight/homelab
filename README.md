# Homelab

This repository is the home for the Docker Compose stacks that run the
homelab. Each directory is deliberately independent: start, update, and
troubleshoot a service from its own directory without having to bring the
whole environment along with it.

The repository contains configuration, not runtime data. Volumes, uploads,
databases, keys, and local environment files live on the host and are backed up
separately.

## Before you start

You will need Docker Engine and the Docker Compose plugin. Most services can be
started from their directory:

```sh
cd <service>
docker compose up -d
```

Check the rendered configuration before changing or deploying a stack:

```sh
docker compose config
```

GitHub Actions runs the same Compose rendering check for every pull request and
push to `main`. It uses empty, temporary environment files only to validate the
structure; deployment credentials remain on the host. Make the **Validate
Compose stacks / Render Compose configurations** check required in the
repository branch-protection rules to prevent invalid Compose changes from
merging.

Several public-facing services share Traefik's external Docker network. Create
it once before starting Traefik or any stack marked **Proxy** below:

```sh
docker network create proxy
```

Start Traefik before services that need it. The other stacks can be deployed
independently.

## Services

| Directory | What it runs | Exposure |
| --- | --- | --- |
| `authentik` | Identity provider and PostgreSQL | Proxy |
| `autokuma` | Uptime Kuma monitor automation | Internal |
| `borgmatic` | Encrypted backups to Borg | Internal |
| `dashlit` | Dashboard | Proxy |
| `forgejo` | Git forge and PostgreSQL | Proxy |
| `grafana` | Dashboards | Internal |
| `homeassistant` | Home Assistant and Mosquitto | Proxy |
| `immich` | Photo library, PostgreSQL, and Valkey | Internal |
| `keycloak` | Identity and access management | Proxy |
| `komodo` | Deployment manager and MongoDB | Proxy |
| `mosquitto` | MQTT broker | Internal |
| `paperless` | Document archive with PostgreSQL, Valkey, Gotenberg, and Tika | Proxy |
| `pyrodactyl` | Pyrodactyl | Internal |
| `technitium` | DNS server | Internal |
| `traefik` | Reverse proxy and ACME certificates | Proxy |
| `tsdproxy` | Tailscale Docker proxy | Internal |
| `uptimekuma` | Availability monitoring | Internal |
| `vaultwarden` | Password manager | Proxy |
| `vikunja` | Task manager and PostgreSQL | Internal |
| `yagpdb` | Discord bot with PostgreSQL and Redis | Proxy |

`komodo-configs` holds Komodo's server and stack definitions, while
`komodo-sops` builds the SOPS-enabled image used by its workflows. The
`renovate` directory contains the shared Renovate preset and its maintenance
helper.

Each stack's README covers its configuration and persistent data. Read it
before its first deployment, particularly for services that need a local
environment file or have an external dependency.

## Secrets and local configuration

Never commit credentials, private keys, decrypted SOPS files, or runtime data.
The repository ignores `.env`, `compose.env`, and `authorized_keys` to make
that easier.

The original local files were intentionally not copied during consolidation:

- `autokuma/.env`
- `forgejo/.env`
- `immich/.env`
- `komodo/compose.env`
- `paperless/.env`
- `vaultwarden/.env`
- `authorized_keys`

Restore or recreate these securely on the deployment host before starting the
affected services. The relevant stack README names the required settings. Do
not treat a missing environment file as a cue to put secrets directly in
`compose.yaml`.

## Backups and recovery

`borgmatic` is the backup stack. It creates logical database dumps, exports
named volumes where needed, and stores encrypted archives in Borg. Its README
explains setup, verification, retention, and recovery.

After adding a service or changing its volumes or database names, update the
Borgmatic database-dump manifest and exclusions, then run both a backup and a
restore test. A backup that has never been restored is only a hopeful copy.

For a full recovery, restore the repository and persistent data first, recreate
the `proxy` network, bring up Traefik, and then start dependent services after
their databases have been restored.

## Updates

Renovate tracks container image updates. Review the generated pull requests,
especially major-version changes and database upgrades. Before updating a
stateful service, make sure its backup is current and read the upstream release
notes.

Use the same cautious loop for manual changes:

1. Render the Compose configuration with `docker compose config`.
2. Take or confirm a current backup for stateful services.
3. Deploy from the stack directory with `docker compose up -d`.
4. Verify the service and its logs before moving on.
