# Borgmatic container scripts

This directory contains the backup container entrypoint and helper scripts.

- `entrypoint.sh` decrypts and prepares runtime configuration.
- `run-backup.sh` coordinates dumps, volume exports, and Borgmatic.
- `run-borg.sh` runs Borg commands with the configured environment.

These scripts access the Docker socket and should be reviewed as
host-administrator code. Test a backup and restore after changing them.
