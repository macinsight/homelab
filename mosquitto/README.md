# Mosquitto

Mosquitto provides an MQTT broker with persistent configuration, data, and logs.

## Run

Review the broker configuration and create local password or ACL files before
starting:

```sh
docker compose up -d
```

Keep credentials private and back up the `config` and `data` volumes.
