# Borgmatic configuration

`config.yaml.template` is the Borgmatic configuration template used by the
backup container. It defines archive sources, exclusions, retention, and
consistency checks.

When adding a stack, update this template and the database dump hooks together.
Do not put repository URLs, passphrases, or storage credentials in this file;
those belong in the encrypted Borg environment configuration.
