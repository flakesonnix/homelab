---
aliases: [MicroVMs, VMs]
tags: [host, network, nixos]
type: reference
---

# MicroVMs (mireo)

[[10-Hosts/mireo|← mireo]] · [[10-Hosts/Network|Network]] · Source: `hosts/mireo/default.nix`, `hosts/mireo/*-microvm.nix`, `microvm-base.nix`, `vm-ips.nix` (shared IP map), `flake.nix`.

All via `microvm.nixosModules.host`, tap→br0, MAC derived from IP, units `microvm@<name>`. IPv4 via dnsmasq DHCP reservation from the same `vm-ips.nix` (no on-guest static); ULA stays static.

## Enabled specs (18)

Configuration membership is not proof that a VM is running; check systemd or
NixFleet for runtime state. All guests receive the shared public CA via
`modules/nixos/lucy-ca.nix`.

| VM | IP | RAM | vCPU | Storage | Service |
|----|----|-----|------|---------|---------|
| grafana | 10.8.0.2 | 768M | 2 | 1G+1G | Prometheus + Grafana with mireo-router dashboard |
| network-services | 10.8.0.3 | 384M | 1 | — | bridge tap stub, no services |
| monerod | 10.8.0.4 | 2304M | 2 | 350G chain | Pruned Monero node + Tor relay `mireoMoneroRelay`, 9001/tcp WAN→VM |
| yammat | 10.8.0.5 | 2304M | 2 | 8G pg +128M | YAMMAT event management :3000 |
| cups | 10.8.0.6 | 512M | 1 | 256M | CUPS IPP print server, Epson ET-2860 + Lexmark — [[40-Guides/Printing|printing guide]] |
| sshkeys | 10.8.0.7 | 256M | 1 | — | Nginx serving SSH public keys |
| uptime-kuma | 10.8.0.9 | 512M | 1 | 1G | Status monitoring :3001 |
| jellyfin | 10.8.0.10 | 2304M | 2 | 16G+4G | Media server :8096, requires host `/data` |
| ntp | 10.8.0.11 | 256M | 1 | — | chrony NTP :123/udp |
| lldap | 10.8.0.12 | 512M | 1 | 512M | LDAP directory `dc=home,dc=arpa` (:3890 + UI :17170) |
| pocket-id | 10.8.0.13 | 512M | 1 | 512M | OIDC provider :1411 |
| artifacts | 10.8.0.20 | 1024M | 2 | 4G+4G | Attic cache + OCI registry |
| communication | 10.8.0.23 | 2304M | 2 | 4G+1G | Matrix Synapse + ntfy |
| remote | 10.8.0.25 | 512M | 1 | 512M | RustDesk relay |
| maps | 10.8.0.27 | 8192M | 8 | 32G+8G | OSM tiles :80 |
| dns | 10.8.0.30 | 384M | 1 | 512M | AdGuard filtering :53, UI :3000 |
| fxsync | 10.8.0.31 | 1024M | 1 | 2G | Firefox Sync :5000, mireo-only; clients use HTTPS on mireo |
| dash | 10.8.0.32 | 1024M | 1 | 512M | Homepage dashboard :8082 |

## Disabled and retired

Eight stub specs are commented out in `hosts/mireo/default.nix`: `cloud` .14,
`management` .15, `devops` .17, `media` .21, `documents` .22, `sync` .26,
`postgres` .28 and `identity` .29. Their IPs/DNS remain reserved in `vm-ips.nix`,
but they do not allocate guest RAM or run services. The enabled `network-services`
VM is itself a service-less bridge stub; DHCP/DNS/PXE run on the host.

Retired: `aptcache` .8 (2026-10-05) and the `kodi` music-box VM (replaced by
host-side Mopidy). Full resource table, including disabled specs: `docs/hosts.md`.

## Ops

```bash
systemctl status microvm@cups
systemctl restart microvm@grafana
journalctl -u microvm@monerod -f
```

NixFleet: `GET /api/v1/hosts/mireo/vms` merges `configured` (manifest) + `runtime` (`systemctl is-active`). See [[50-NixFleet/Manifest-API|Manifest & API]].

New VM: [[40-Guides/New-Host-VM|New host / VM]] (`just new-vm`, then register the IP in `vm-ips.nix`).
