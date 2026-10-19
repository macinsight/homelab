# Home Assistant

Home Assistant runs alongside a Mosquitto MQTT broker. Configuration and broker
state are persisted in named volumes.

## Run

Create the external `proxy` network when exposing Home Assistant through a
reverse proxy, then start the stack:

```sh
docker compose up -d
```

Manage Home Assistant configuration and MQTT credentials as private runtime
data. Back up `data`, `mqttconfig`, `mqttdata`, and `mqttlog` before upgrades.
