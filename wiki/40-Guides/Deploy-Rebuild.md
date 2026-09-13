---
aliases: [Deploy, Rebuild, deploy-rs]
tags: [guide, nixos]
type: guide
---

# Deploy & rebuild

[[40-Guides/Guides-MOC|← Guides]] · [[00-Start/Quickstart|Quickstart]]

## x270 locally (preferred, nh)

```bash
nix run .#rebuild
# just rebuild
sudo nixos-rebuild switch --flake .#x270
```

## deploy-rs (custom activate + NIX_PATH stub, flake.nix:474)

```bash
nix run .#deploy-x270    # localhost, root
nix run .#deploy-mireo   # 10.8.0.1, root
nix run .#deploy-nyagate # db210.org, lucy → root
just deploy-all
deploy .#mireo           # directly via deploy-rs
```

Stub background: `nixos-rebuild-ng` reexec needs `nixos-config` in NIX_PATH → empty stub file until the `nix-settings.nix` etc. entry takes effect after reboot.

## Before deploying

```bash
nix run .#check-light
nix run .#check
nix fmt && statix check
```

## After deploying

```bash
nixos-rebuild list-generations
systemctl --failed
journalctl -b -p err
# mireo:
curl -sk https://10.8.0.1:8443/api/v1/hosts/mireo/health | jq
```

If red → [[40-Guides/Troubleshooting|Troubleshooting]].
