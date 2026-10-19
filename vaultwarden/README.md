# Vaultwarden

Vaultwarden is a Bitwarden-compatible password manager exposed through the
external `proxy` network.

## Configure

The `.env` file is SOPS-encrypted. Update it only with SOPS and an authorized
age identity, and decrypt it only for the deployment runtime. Never commit an
age private key or a plaintext environment file.

Start the stack after making the decrypted configuration available:

```sh
docker compose up -d
```

Back up the `data` volume securely; it contains password-manager state.