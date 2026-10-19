# Keycloak

Keycloak is an identity and access management service backed by PostgreSQL and
exposed through the external `proxy` network.

## Configure

Create local environment configuration for `KEYCLOAK_ADMIN_USER`,
`KEYCLOAK_ADMIN_PASS`, and `KEYCLOAK_DB_PASSWORD`. Use unique, long values and
do not commit them.

Start the stack:

```sh
docker compose up -d
```
