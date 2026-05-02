# Secrets

Repo uses `sops-nix` for runtime-decrypted secrets.

## One-time Setup

```bash
./setup-sops.sh omen          # Generate age key pair in .sops/keys.txt
```

This generates an age key pair and prints the public key.
Update `.sops.yaml` with that public key if it differs from the existing one.

## Creating Secrets

1. Generate a blank file:

```bash
touch hosts/omen/secrets.yaml
```

2. Encrypt and edit it:

```bash
SOPS_AGE_KEY_FILE=.sops/keys.txt sops hosts/omen/secrets.yaml
```

3. Use the Asterisk template from `modules/nixos/secrets.yaml.example` as reference.

## Activating in Host Config

In your host data file (e.g. `data/hosts/omen/services.nix`):

```nix
{
  lucy.secrets = {
    enable = true;
    sopsFile = ../../../hosts/omen/secrets.yaml;
  };
}
```

## Asterisk SIP Passwords

`services.asteriskLocal` supports sops-nix templated config. When `secrets.enable = true`,
config files are rendered at runtime via `sops.templates` — passwords never touch the Nix store.

```nix
services.asteriskLocal = {
  enable = true;
  secrets.enable = true;
  phones = {
    desk1 = {
      extension = "1001";
      passwordSecret = "asterisk/phones/desk1";  # References key in secrets.yaml
    };
  };
};
```

Corresponding entry in `hosts/omen/secrets.yaml` (encrypted):

```yaml
asterisk:
  phones:
    desk1: "s3cret-p4ssw0rd"
```

## Key Rotation

1. Generate new key: `age-keygen -o .sops/keys.txt`
2. Update public key in `.sops.yaml`
3. Re-encrypt all secrets: `SOPS_AGE_KEY_FILE=.sops/keys.txt sops --rotate -i hosts/omen/secrets.yaml`
4. Deploy new key to target host: `sudo cp .sops/keys.txt /etc/sops/age/keys.txt`

## Deploying Keys to Host

```bash
sudo mkdir -p /etc/sops/age
sudo cp .sops/keys.txt /etc/sops/age/keys.txt
sudo chmod 600 /etc/sops/age/keys.txt
```

## Notes

- `lucy.secrets.enable=true` without `lucy.secrets.sopsFile` fails with a clear assertion.
- Plaintext passwords in `data/hosts/**` are blocked by the `no-plaintext-host-passwords` pre-commit check.
- Use `passwordSecret` (key path) instead of `password` (plaintext) for sops-nix integration.
