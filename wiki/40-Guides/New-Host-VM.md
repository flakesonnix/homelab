---
aliases: [New host, Scaffolding]
tags: [guide, nixos]
type: guide
---

# New host

[[40-Guides/Guides-MOC|← Guides]] · Script `scripts/new-host.sh`.

```bash
just new-host myhost   # → hosts/<name>/ (host.nix, hardware.nix, default.nix)
./scripts/new-host.sh host myhost
```

## New host checklist

- [ ] Check `hosts/<name>/{host.nix,hardware-configuration.nix,default.nix}`
- [ ] Create `data/hosts/<name>/{settings.nix,roles.nix,module-flags.nix,packages.nix}`
- [ ] `flake.nix`: `mkHost` + `nixosConfigurations.<name>` + `deploy.nodes.<name>` + menu entry
- [ ] Check `topology.nix` + [[50-NixFleet/Manifest-API|Manifest]] (exclude live ISO if applicable)
- [ ] `nix run .#check-light` → `nixos-rebuild build --flake .#<name>`
- [ ] sops if needed: [[40-Guides/Secrets-Guide|Secrets guide]]
- [ ] Copy the template: [[99-Meta/Templates/Host-Template|Host template]]

> MicroVM scaffolding (`just new-vm`, `microvm-base.nix`) was removed with Purr — there is currently no VM builder. Static IPs/DNS for the existing VMs live in the dnsmasq `staticHosts` map in `data/hosts/mireo/settings.nix`.
