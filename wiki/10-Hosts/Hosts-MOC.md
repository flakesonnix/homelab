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

- [[10-Hosts/p53|p53]] — desktop/gaming laptop
- [[10-Hosts/mireo|mireo]] — router/server + VMs
- [[10-Hosts/MicroVMs|MicroVMs]] — 18 configured VMs on mireo, eight more specs disabled
- [[10-Hosts/Network|Network]] — topology, IPs, DNS/DHCP

Network SVGs: `nix build .#topology` → `result/{main,network}.svg`; CI updates the copies in `docs/topology/`. See [[60-Reference/Flake-CI-Topology|Flake · CI · topology]].
Source: `docs/hosts.md`, `topology.nix`, `flake.nix`.
