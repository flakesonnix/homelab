---
aliases: [Glossary, Terms]
tags: [start, reference]
type: reference
---

# Glossary

[[Home|← Home]]

| Term | Meaning | Where |
|---------|-----------|----|
| Role | Unit of intent (`data/roles/*.nix`), e.g. `desktop`, `gaming` | [[30-Data-Model/Roles-Bundles-Presets|Roles]] |
| Bundle | Home Manager slice (`data/bundles/*.nix`): `core`, `desktop`, `dev` | [[30-Data-Model/Roles-Bundles-Presets|Roles]] |
| Preset | Host flag set (`data/presets/*.nix`): `gaming-base/-performance/-steam` | [[30-Data-Model/Roles-Bundles-Presets|Roles]] |
| Module flag | `lucy.*` / `hq.*` option, e.g. `lucy.gaming.enable` | [[20-Modules/NixOS-Modules|NixOS modules]] |
| applyHost / applyHome | Framework functions (`lib/framework`) → merge `data/` into NixOS/HM | [[60-Reference/Directory-Structure|Directory structure]] |
| Manifest | `nixfleet/artifacts/manifest.json` — pure-Nix host/VM catalog | [[50-NixFleet/Manifest-API|Manifest & API]] |
| ui.json | Navigation/widgets/RBAC generated from Nix | [[50-NixFleet/Manifest-API|Manifest & API]] |
| deploy-rs | Deployment (`flake.deploy.nodes`) with custom activate + NIX_PATH stub | [[40-Guides/Deploy-Rebuild|Deploy]] |
| lanzaboote | Secure Boot (`/var/lib/sbctl`) | [[10-Hosts/x270|x270]] |
| sops-nix / age | Secrets (`/etc/sops/age/keys.txt`, `.sops.yaml`) | [[40-Guides/Secrets-Guide|Secrets]] |
| br0 | Bridge mireo LAN 10.8.0.1/24 + fd00:cafe:1::1/64 | [[10-Hosts/Network|Network]] |
| microvm.nix | QEMU tap→br0 VMs (`flake.nix:193`) | [[10-Hosts/MicroVMs|MicroVMs]] |
| Stylix | base16 cyberdeck theming | [[20-Modules/Home-Modules|Home modules]] |
| Niri | Wayland compositor (KDL `modules/home/niri.nix`) | [[20-Modules/Home-Modules|Home modules]] |
