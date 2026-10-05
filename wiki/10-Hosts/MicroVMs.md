---
aliases: [MicroVMs, VMs]
tags: [host, network, nixos]
type: reference
---

# MicroVMs (mireo)

[[10-Hosts/mireo|← mireo]] · [[10-Hosts/Network|Network]] · Source: `hosts/mireo/*-microvm.nix`, `microvm-base.nix`, `vm-ips.nix` (shared IP map), `flake.nix:193`.

All via `microvm.nixosModules.host`, tap→br0, MAC derived from IP, units `microvm@<name>`. IPv4 via dnsmasq DHCP reservation from the same `vm-ips.nix` (no on-guest static); ULA stays static.

## Table

| VM | IP | RAM | vCPU | Storage | Service |
|----|----|-----|------|---------|---------|
| grafana | 10.8.0.2 | 768M | 2 | 1G+1G | Prometheus + Grafana with mireo-router dashboard |
| network-services | 10.8.0.3 | 384M | 1 | — | bridge tap stub, no services |
| monerod | 10.8.0.4 | 2304M | 2 | 350G chain | Pruned Monero node + Tor relay `mireoMoneroRelay`, 9001/tcp WAN→VM |
| yammat | 10.8.0.5 | 2304M | 2 | 8G pg +128M | YAMMAT event management :3000 |
| cups | 10.8.0.6 | 512M | 1 | 256M | CUPS IPP print server, Epson ET-2860 + Lexmark — [[40-Guides/Printing|printing guide]] |
| sshkeys | 10.8.0.7 | 256M | 1 | — | Nginx serving SSH public keys |
| … | … | … | … | … | … (26 VMs total as of Oct 2026 — uptime-kuma .9, jellyfin .10, ntp .11, lldap .12, pocket-id .13, cloud .14, management .15, devops .17, artifacts .20, media .21, documents .22, communication .23, remote .25, sync .26, maps .27, postgres .28, identity .29, dns .30, dash .32 — full map in `hosts/mireo/vm-ips.nix`; retired: aptcache .8 (2026-10-05), kodi music-box (replaced by Mopidy)) |
| lldap | 10.8.0.12 | 512M | 1 | 512M | LDAP directory `dc=home,dc=arpa` (:3890 + UI :17170) |

## Ops

```bash
systemctl status microvm@cups
systemctl restart microvm@grafana
journalctl -u microvm@monerod -f
```

NixFleet: `GET /api/v1/hosts/mireo/vms` merges `configured` (manifest) + `runtime` (`systemctl is-active`). See [[50-NixFleet/Manifest-API|Manifest & API]].

New VM: [[40-Guides/New-Host-VM|New host / VM]] (`just new-vm`, then register the IP in `vm-ips.nix`).
