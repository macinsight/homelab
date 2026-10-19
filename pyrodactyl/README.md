# Pyrodactyl

Pyrodactyl is deployed from the Compose definition in this directory.

## Configure and run

Review `compose.yaml` for required image, network, volume, and environment
settings. Store all credentials and service-specific runtime configuration
outside the repository, then start the stack:

```sh
docker compose up -d
```

Back up persistent volumes before updating the service.
