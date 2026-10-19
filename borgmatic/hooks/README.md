# Borgmatic hooks

`dump-databases.sh` creates logical PostgreSQL, MariaDB, and MongoDB exports for
the stacks included in backups.

Keep its service list synchronized with `borgmatic/config.yaml.template` and
the Compose stacks. Test database restoration after changing a service name,
database engine, or dump procedure.
