---
aliases: [live-iso, Live-ISO, Installer]
tags: [host, nixos]
type: host
host: live
role: Installer ISO
deploy: nix build .#packages.x86_64-linux.live-iso
---

# live-iso

[[10-Hosts/Hosts-MOC|← Hosts]]

Installer ISO, not a fleet host (excluded from `nixfleetArtifacts`).

- Modules: `fonts`, `niri`, `waybar`, `hm-base`, home-manager, sops, lanzaboote (grub/systemd-boot forced off)
- `hosts/live-iso/` + `liveSpecialArgs` (x270 args + nixpkgs/yammat)
- Build: `nix build .#packages.x86_64-linux.live-iso`

```bash
nix build .#packages.x86_64-linux.live-iso
ls result/iso/
```
