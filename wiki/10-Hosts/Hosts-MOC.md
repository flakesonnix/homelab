---
aliases: [Hosts, Hosts overview]
tags: [moc, host]
type: moc
---

# Hosts overview

[[Home|← Home]]

```dataview
TABLE ip AS IP, role AS Role, deploy AS Deploy
FROM "wiki/10-Hosts"
WHERE type = "host"
SORT file.name ASC
```

## Map

- [[10-Hosts/x270|x270]] — desktop/gaming laptop
- [[10-Hosts/mireo|mireo]] — router/server + VMs
- [[10-Hosts/nyagate|nyagate]] — remote server
- [[10-Hosts/live-iso|live-iso]] — installer ISO
- [[10-Hosts/MicroVMs|MicroVMs]] — 7 VMs on mireo
- [[10-Hosts/Network|Network]] — topology, IPs, DNS/DHCP

Network SVGs: `nix build .#topology` → `docs/topology/{main,network}.svg` — see [[60-Reference/Flake-CI-Topology|Flake · CI · topology]].
Source: `docs/hosts.md`, `topology.nix`, `flake.nix`.
