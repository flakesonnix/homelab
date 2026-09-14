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
nix run .#setup-sops x270
# adopt the .sops.yaml snippet from the output
SOPS_AGE_KEY_FILE=.sops/keys.txt sops hosts/x270/secrets.yaml

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
SOPS_AGE_KEY_FILE=.sops/keys.txt sops hosts/x270/secrets.yaml
# Rotation: generate a new key (delete .sops/keys.txt first), update .sops.yaml,
SOPS_AGE_KEY_FILE=<old-key> sops updatekeys hosts/x270/secrets.yaml
```

## Initrd SSH (:2222, remote unlock)

```bash
sudo mkdir -p /etc/secrets/initrd
sudo ssh-keygen -t ed25519 -f /etc/secrets/initrd/ssh_host_ed25519_key -N ""
sudo chmod 600 /etc/secrets/initrd/ssh_host_ed25519_key
```

## WireGuard mireo↔nyagate (10.66.0.0/30, public edge db210.org)

Private keys only in sops (`hosts/{mireo,nyagate}/secrets.yaml`), public keys + endpoints plain in settings.
nyagate DNATs 80/443/25565/19132(udp) → `10.66.0.2` (mireo: Minecraft Java + Geyser aus `~/mcserver`), Caddy on mireo serves `yammat.db210.org` + `grafana.db210.org` with auto-TLS (needs A records `*.db210.org → 188.220.148.24`).

```bash
nix run .#deploy-nyagate   # wg0 .1 + NAT first
nix run .#deploy-mireo     # wg0 .2 + Caddy public vhosts
ssh root@10.8.0.1 'wg show wg0'; ssh root@db210.org 'wg show wg0'
```

`allowedIPs=["10.66.0.1/32"]` — never `0.0.0.0/0` (would hijack LAN/NFS/IPv6). Rollback: `systemctl stop wireguard-wg0`.
