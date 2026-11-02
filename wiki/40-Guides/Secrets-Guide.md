---
aliases: [Secrets, sops, age]
tags: [guide, secret, nixos]
type: guide
---

# Secrets (sops-nix / age)

[[40-Guides/Guides-MOC|← Guides]] · Source `docs/secrets.md`, `.sops.yaml`, `modules/nixos/sops.nix`.

## How it works

The private age key lives only on the target host at `/etc/sops/age/keys.txt`. The public key is registered in `.sops.yaml`. `hosts/<host>/secrets.yaml` is an encrypted YAML file checked into the repo. sops-nix decrypts it at activation time and exposes secrets as files under `/run/secrets/`.

## Setup

```bash
nix run .#setup-sops p53
# adopt the .sops.yaml snippet from the output
SOPS_AGE_KEY_FILE=.sops/keys.txt sops hosts/p53/secrets.yaml

sudo mkdir -p /etc/sops/age
sudo cp .sops/keys.txt /etc/sops/age/keys.txt
sudo chmod 600 /etc/sops/age/keys.txt
```

`.sops/keys.txt` is gitignored — never commit private keys. Only the encrypted `secrets.yaml` files are committed.

## Module

```nix
lucy.secrets = {
  enable = true;
  sopsFile = ./secrets.yaml;
};
```

## Asterisk secrets (kept out of the Nix store)

```nix
services.asteriskLocal = {
  secrets.enable = true;
  phones.saal1 = { extension = "1001"; passwordSecret = "asterisk/phones/saal1"; };
};
```

```yaml
asterisk:
  phones:
    saal1: "secret"
```

## Editing / rotation

```bash
SOPS_AGE_KEY_FILE=.sops/keys.txt sops hosts/p53/secrets.yaml
# Rotation: generate a new key (delete .sops/keys.txt first), update .sops.yaml,
SOPS_AGE_KEY_FILE=<old-key> sops updatekeys hosts/p53/secrets.yaml
```

## Initrd SSH (:2222, remote unlock)

```bash
sudo mkdir -p /etc/secrets/initrd
sudo ssh-keygen -t ed25519 -f /etc/secrets/initrd/ssh_host_ed25519_key -N ""
sudo chmod 600 /etc/secrets/initrd/ssh_host_ed25519_key
```

## Retired transit secrets

The VPS transit is removed. Its encrypted keys remain unreferenced; see
`docs/secrets.md`. mireo still needs sops for its unrelated service secrets.
