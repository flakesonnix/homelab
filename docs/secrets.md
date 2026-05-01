# Secrets

Repo uses `sops-nix` for runtime-decrypted secrets.

## Setup

1. Generate age key:

```bash
./setup-sops.sh
```

2. Create host secrets file (encrypted):

- Example path: `hosts/omen/secrets.yaml`

3. Point config at file:

- Set `lucy.secrets.enable = true;`
- Set `lucy.secrets.sopsFile = ./hosts/omen/secrets.yaml;` (path from flake root)

## Notes

- Keep secrets out of Nix store: use `sops.secrets.<name>` files or `sops.templates` for config files.
- If `lucy.secrets.enable=true` and `lucy.secrets.sopsFile=null`, eval fails with clear assertion.
