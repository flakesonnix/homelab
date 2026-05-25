# Secrets

Secrets are managed with [sops-nix](https://github.com/Mic92/sops-nix) using [age](https://age-encryption.org/) keys.

## How it works

1. An age key pair is generated per environment. The private key lives on the target host at `/etc/sops/age/keys.txt`.
2. The public key is registered in `.sops.yaml`, which tells SOPS which key can decrypt each secrets file.
3. `hosts/<host>/secrets.yaml` is an encrypted YAML file checked into the repo. Only the holder of the matching private key can decrypt it.
4. sops-nix decrypts the file at activation time and exposes secrets as files under `/run/secrets/`.

## Initial setup

```bash
# Generate age key pair (stores private key in .sops/keys.txt)
./setup-sops.sh omen

# Update .sops.yaml with the printed public key, then create the secrets file
SOPS_AGE_KEY_FILE=.sops/keys.txt sops hosts/omen/secrets.yaml
```

The script outputs the public key and the exact `.sops.yaml` snippet to add. Current `.sops.yaml` covers `hosts/.*/secrets.yaml`.

## Deploy private key to host

```bash
sudo mkdir -p /etc/sops/age
sudo cp .sops/keys.txt /etc/sops/age/keys.txt
sudo chmod 600 /etc/sops/age/keys.txt
```

The `.sops/keys.txt` file is in `.gitignore` — never commit private keys.

## Using the module

`modules/nixos/sops.nix` wraps sops-nix with a simpler interface:

```nix
lucy.secrets = {
  enable = true;
  sopsFile = ./secrets.yaml;          # path to encrypted file
  ageKeyPath = /etc/sops/age/keys.txt; # default, usually omit
};
```

The module asserts `sopsFile != null` when enabled, so missing config surfaces as a clear eval error rather than a runtime failure.

## Asterisk secrets

When `services.asteriskLocal.secrets.enable = true`, phone passwords are kept out of the Nix store. The pjsip.conf and extensions.conf are rendered as sops templates with password placeholders resolved at activation time.

Requires `lucy.secrets.enable = true` (or `sops.defaultSopsFile` set directly).

Each phone's `passwordSecret` value is the sops secret key, e.g.:

```nix
services.asteriskLocal = {
  secrets.enable = true;
  phones.saal1 = {
    extension = "1001";
    passwordSecret = "asterisk/phones/saal1";
  };
};
```

The corresponding entry in `secrets.yaml`:

```yaml
asterisk:
  phones:
    saal1: "mysecretpassword"
```

## Editing secrets

```bash
SOPS_AGE_KEY_FILE=.sops/keys.txt sops hosts/omen/secrets.yaml
```

SOPS opens the decrypted file in `$EDITOR`, re-encrypts on save.

## Key rotation

1. Generate new key: `./setup-sops.sh omen` (will error if key exists — delete `.sops/keys.txt` first)
2. Update public key in `.sops.yaml`
3. Re-encrypt all affected secrets files: `SOPS_AGE_KEY_FILE=<old-key> sops updatekeys hosts/omen/secrets.yaml`
4. Deploy new private key to host, rebuild
