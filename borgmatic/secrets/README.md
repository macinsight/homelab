# Borgmatic secrets

This directory holds private runtime material that must not be committed:

- `age.key` - an age private identity used for SOPS decryption.
- `storagebox_ed25519` - the dedicated Borg Storage Box SSH private key.
- `known_hosts` - the verified Storage Box host key.
- `borg.env.sops` - the encrypted Borg repository configuration.

Restrict private key files to mode `0600`. The `.gitignore` permits this README
and `.gitkeep` only; keep every other file private.
