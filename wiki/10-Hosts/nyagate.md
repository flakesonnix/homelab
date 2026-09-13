---
aliases: [nyagate, db210]
tags: [host, nixos, server]
type: host
host: nyagate
ip: 188.220.148.24
hostname: db210.org
role: Remote server (QEMU VM)
roles: []
deploy: nix run .#deploy-nyagate
---

# nyagate

> [!info] Profile
> **Role:** remote server · **Host:** `db210.org` · **IP:** `188.220.148.24/32` eth0, GW 10.0.0.1
> **Deploy:** `nix run .#deploy-nyagate` (ssh as lucy → sudo to root)

[[10-Hosts/Hosts-MOC|← Hosts]]

## Features

- Minimal server profile (`lucy.base.isServer = true`, no desktop/home-manager)
- Static IPv4 + GRUB on /dev/vda (BIOS, QEMU guest profile)
- OpenSSH, user `lucy` (wheel/sudo) + shared repo SSH key (also authorizes root, key-only)
- stateVersion 26.11 (matches initial install)

## Files

- `data/hosts/nyagate/settings.nix` — hostname, static network, GRUB, SSH, topology
- `data/hosts/nyagate/packages.nix` — server CLI tools (mirrors mireo)
- `hosts/nyagate/host.nix` + `hardware-configuration.nix` (imported from on-host `nixos-generate-config`)

```bash
nix run .#deploy-nyagate
deploy .#nyagate
```
