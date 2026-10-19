# Komodo configuration

This directory contains Komodo server and stack definitions used to manage the
Compose repositories.

## Files

- `servers.toml` defines managed hosts.
- `stacks.toml` defines deployed stacks and their source repositories.

Keep webhook secrets, administrator tokens, and environment blocks out of the
tracked configuration. Supply them through Komodo's secret management or an
encrypted SOPS file instead.
