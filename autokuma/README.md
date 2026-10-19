# AutoKuma

AutoKuma manages Uptime Kuma monitors from Docker labels. Its Compose definition
persists application state in the `data` volume.

## Configure and run

Review `compose.yaml` for the target Uptime Kuma URL and credentials, then start
the service:

```sh
docker compose up -d
```

Do not commit API keys or generated AutoKuma state.
