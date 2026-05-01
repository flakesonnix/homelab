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

## Asterisk

`services.asteriskLocal` supports sops-nix templated config to avoid storing SIP passwords in the Nix store.

Example:

```nix
{
  lucy.secrets = {
    enable = true;
    sopsFile = ./hosts/omen/secrets.yaml;
  };

  services.asteriskLocal = {
    enable = true;
    secrets.enable = true;
    phones = {
      desk1 = {
        extension = "1001";
        passwordSecret = "asterisk/phones/desk1";
      };
    };
  };
}
```

In `hosts/omen/secrets.yaml`, add key `asterisk/phones/desk1`.

## Repo Checks

`nix flake check` includes `no-plaintext-host-passwords` which fails if it finds `password = "..."` in `data/hosts/**`.
