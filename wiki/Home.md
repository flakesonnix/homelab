---
aliases: [Home, Start page]
tags: [moc, start]
type: moc
---

# 🐾 dotfiles Knowledge Base

> NixOS homelab — lucy's NixOS config. As of Sep 2026.
> Vault root. Branch out into everything from here.

## 🗺️ Map

- [[00-Start/Welcome|Welcome]] — what this is, how to use the vault
- [[00-Start/Quickstart|Quickstart]] — rebuild / deploy in 5 min
- [[00-Start/Just-Cheatsheet|Just cheatsheet]] — all `just` / `nix run` commands
- [[00-Start/Glossary|Glossary]] — terms: role, bundle, preset, manifest…

## 🖥️ Hosts

- [[10-Hosts/Hosts-MOC|Hosts overview]] — map of all machines
- [[10-Hosts/x270|x270]] — ThinkPad X270, desktop/gaming (dynamic IP via DHCP)
- [[10-Hosts/mireo|mireo]] — server/router + 7 microVMs (10.8.0.1)
- [[10-Hosts/nyagate|nyagate]] — remote server QEMU (db210.org)
- [[10-Hosts/live-iso|live-iso]] — installer ISO
- [[10-Hosts/MicroVMs|MicroVMs]] — grafana … aptcache in detail
- [[10-Hosts/Network|Network]] — 10.8.0.0/24, br0, NAT, IPv6, Tailscale

## 🧩 Modules & data model

- [[20-Modules/Modules-MOC|Modules overview]] — 24 NixOS + 6 home modules
- [[20-Modules/NixOS-Modules|NixOS modules table]] — all options at a glance
- [[20-Modules/Home-Modules|Home modules]] — niri, waybar, stylix, ssh, opencode, dunst
- [[20-Modules/Gaming-Stack|Gaming stack]] — presets + 6 submodules
- [[30-Data-Model/Data-Model|Data model]] — `data/` as single source of truth
- [[30-Data-Model/Roles-Bundles-Presets|Roles → bundles + presets]] — composition logic

## 📖 Guides

- [[40-Guides/Guides-MOC|Guides overview]]
- [[40-Guides/Deploy-Rebuild|Deploy & rebuild]] — nh, deploy-rs, troubleshooting
- [[40-Guides/Secrets-Guide|Secrets (sops/age)]] — setup, rotation, WireGuard
- [[40-Guides/New-Host-VM|New host / new VM]] — `scripts/new-host.sh`
- [[40-Guides/Printing|Printing]] — CUPS VM 10.8.0.6
- [[40-Guides/Audio-Latency|Audio latency]] — PipeWire/gaming tuning
- [[40-Guides/Apt-Cache|APT cache]] — proxy 10.8.0.8:3142
- [[40-Guides/NFS-Client|NFS client]] — mounting /data
- [[40-Guides/Troubleshooting|Troubleshooting]] — common errors + fixes

## 🐾 NixFleet

- [[50-NixFleet/NixFleet-MOC|NixFleet overview]] — M1 control plane (Go API+agent :8443)
- [[50-NixFleet/Manifest-API|Manifest & API]] — manifest.json/ui.json, endpoints, frontend

## 📐 Reference

- [[60-Reference/Directory-Structure|Directory structure]] — where everything lives
- [[60-Reference/Flake-CI-Topology|Flake · CI · topology]] — inputs, jobs, SVGs
- [[99-Meta/Dataview-Queries|Dataview queries]] — ready-to-copy queries

---

## ✅ Dataview: open tasks (tag = #todo)

```dataview
TASK FROM "wiki"
WHERE !completed
GROUP BY file.link
LIMIT 20
```

## 🕸️ Graph tip

`Ctrl+G` → open graph. Colors: `#host` blue, `#module` purple, `#guide` green, `#nixfleet` orange, `#network` light blue. See `.obsidian/graph.json`.
