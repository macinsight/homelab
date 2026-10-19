# Komodo SOPS image

This directory builds an image that adds SOPS support to Komodo workflows.

## Build

Build it from this directory:

```sh
docker build -t komodo-sops .
```

Provide age identities and decrypted configuration only at runtime. Never bake
private keys or plaintext secrets into the image.
