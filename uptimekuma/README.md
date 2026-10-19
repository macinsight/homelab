# Uptime Kuma

Uptime Kuma monitors service availability and stores its data in the `data`
volume.

## Run

Create the external `proxy` network if you expose the web interface through
Traefik, then start the stack:

```sh
docker compose up -d
```

Back up the `data` volume and keep notification-provider credentials in Uptime
Kuma or external secret storage.
