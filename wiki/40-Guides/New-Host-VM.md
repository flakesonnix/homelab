---
aliases: [New host, New VM, Scaffolding]
tags: [guide, nixos]
type: guide
---

# New host / new VM

[[40-Guides/Guides-MOC|← Guides]] · Script `scripts/new-host.sh`.

```bash
just new-host myhost   # → hosts/<name>/ (host.nix, hardware.nix, default.nix)
just new-vm myvm       # → hosts/mireo/<name>-microvm.nix, 10.8.0.x
./scripts/new-host.sh host myhost
./scripts/new-host.sh vm myvm
```

## New host checklist

- [ ] Check `hosts/<name>/{host.nix,hardware-configuration.nix,default.nix}`
- [ ] Create `data/hosts/<name>/{settings.nix,roles.nix,module-flags.nix,packages.nix}`
- [ ] `flake.nix`: `mkHost` + `nixosConfigurations.<name>` + `deploy.nodes.<name>` + menu entry
- [ ] Check `topology.nix` + [[50-NixFleet/Manifest-API|Manifest]] (exclude live ISO if applicable)
- [ ] `nix run .#check-light` → `nixos-rebuild build --flake .#<name>`
- [ ] sops if needed: [[40-Guides/Secrets-Guide|Secrets guide]]
- [ ] Copy the template: [[99-Meta/Templates/Host-Template|Host template]]

## New microVM checklist

- [ ] Derive `hosts/mireo/<name>-microvm.nix` from `microvm-base.nix` (mem/vcpu/volumes, IP, ports)
- [ ] Merge `microvm.vms.<name>` into the mireo host, check firewall/bridge
- [ ] dnsmasq host record (name→10.8.0.x) in `data/hosts/mireo/settings.nix`
- [ ] `nix run .#deploy-mireo` → `systemctl status microvm@<name>`
- [ ] [[50-NixFleet/Manifest-API|Manifest]] lists the VM (hasVms via `attrNames`)

Template: [[99-Meta/Templates/Host-Template|Host template]].
