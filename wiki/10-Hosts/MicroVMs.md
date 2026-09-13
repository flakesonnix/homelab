---
aliases: [MicroVMs, VMs]
tags: [host, network, nixos]
type: reference
---

# MicroVMs (mireo, 7×)

[[10-Hosts/mireo|← mireo]] · [[10-Hosts/Network|Network]] · Static IPs/DNS: dnsmasq `staticHosts` map in `data/hosts/mireo/settings.nix` (no Nix VM definitions right now; `microvm.nixosModules.host` + tap→br0 via `flake.nix:193` when they return).

All via `microvm.nixosModules.host`, tap→br0, MAC derived from IP, units `microvm@<name>`.

## Table

| VM | IP | RAM | vCPU | Storage | Service |
|----|----|-----|------|---------|---------|
| grafana | 10.8.0.2 | 768M | 2 | 1G+1G | Prometheus + Grafana with mireo-router dashboard |
| network-services | 10.8.0.3 | 384M | 1 | — | bridge tap stub, no services |
| monerod | 10.8.0.4 | 2304M | 2 | 350G chain | Pruned Monero node + Tor relay `mireoMoneroRelay`, 9001/tcp WAN→VM |
| yammat | 10.8.0.5 | 2304M | 2 | 8G pg +128M | YAMMAT event management :3000 |
| cups | 10.8.0.6 | 512M | 1 | 256M | CUPS IPP print server, Epson ET-2860 + Lexmark — [[40-Guides/Printing|printing guide]] |
| sshkeys | 10.8.0.7 | 256M | 1 | — | Nginx serving SSH public keys |
| aptcache | 10.8.0.8 | 512M | 1 | 8G | apt-cacher-ng caching proxy — `docs/apt-cache.md` |

## Ops

```bash
systemctl status microvm@cups
systemctl restart microvm@grafana
journalctl -u microvm@monerod -f
```

NixFleet: `GET /api/v1/hosts/mireo/vms` merges `configured` (manifest) + `runtime` (`systemctl is-active`). See [[50-NixFleet/Manifest-API|Manifest & API]].

New VM: no builder right now — see [[40-Guides/New-Host-VM|New host]] guide.
