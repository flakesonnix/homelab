---
aliases: [mireo, Router, Homeserver]
tags: [host, nixos, network, nixfleet, server]
type: host
host: mireo
ip: 10.8.0.1
wan: 192.168.178.25
role: Homeserver / LAN router + 7 microVMs
roles: []
deploy: nix run .#deploy-mireo
---

# mireo

> [!info] Profile
> **Role:** router/server · **LAN:** `10.8.0.1/24` + `fd00:cafe:1::1/64` (br0) · **WAN:** `192.168.178.25`
> **Deploy:** `nix run .#deploy-mireo` · **NixFleet:** API+agent `:8443`

[[10-Hosts/Hosts-MOC|← Hosts]] · [[10-Hosts/MicroVMs|MicroVMs]] · [[10-Hosts/Network|Network]] · [[50-NixFleet/NixFleet-MOC|NixFleet]]

## Features

- NAT for 10.8.0.0/24 + IPv6 via NAT66 (FritzBox PD configured but currently not landing — br0 is ULA-only, all LAN v6 egress masqueraded), systemd-networkd
- dnsmasq: DHCPv4/stateful DHCPv6 (explicit ULA range)/DNS/RA+SLAAC (constructor:br0) (`bindsTo sys-devices-virtual-net-br0.device` fix)
- PXE boot via dnsmasq (iPXE from nixpkgs, netboot.xyz menu; iVentoy removed Sep 2026)
- NFS export of `/data` → 10.8.0.0/24, Avahi `_nfs._tcp`, Netdata :19999, node_exporter :9100
- libvirtd for virt-manager remote (Weg A): `qemu+ssh://root@10.8.0.1/system`, `allowedBridges=["br0"]`
- CLI tools: tcpdump, mtr, nmap, iperf3, ethtool, socat, btop, jq, lsof, sysstat, smartmontools
- `lucy.base.isServer = true` (no desktop)

## NixFleet M1 (Sep 2026)

`lucy.nixfleet.enable=true; role="api"` in `data/hosts/mireo/settings.nix` — API on 8443 (`DynamicUser`, `StateDirectory=nixfleet`) + agent (`systemd`+`journal`+`metrics`). Firewall on br0 allows 8443. `artifactsDir=../../../nixfleet/artifacts`, `webDir` via `nixfleetPkgs.web` (currently null to avoid deepSeq overflow, only built as a package).

## Reverse proxy (Caddy :80)

One entrypoint for all web UIs: `http://<name>.home.arpa` (DNS from dnsmasq, no HTTPS — no public CA for `.home.arpa`, LAN-only via firewall).

| URL | Target |
|-----|--------|
| grafana.home.arpa | 10.8.0.2:3000 |
| prometheus.home.arpa | 10.8.0.2:9090 |
| yammat.home.arpa | 10.8.0.5:3000 |
| cups.home.arpa | 10.8.0.6:631 (web UI; IPP printing stays direct) |
| sshkeys.home.arpa | 10.8.0.7:80 |
| aptcache.home.arpa | 10.8.0.8:3142 |
| netdata.home.arpa | mireo :19999 |

Source: `webUIs` map in `data/hosts/mireo/settings.nix` → `services.caddy.virtualHosts`.

## libvirt (virt-manager remote target, Weg A)

`virtualisation.libvirtd` in `data/hosts/mireo/settings.nix:112` (`enable=true`, `allowedBridges=["br0"]`, `qemu.vhostUserPackages=[virtiofsd]`) — x270 verbindet via `qemu+ssh://root@10.8.0.1/system`. Neue Gäste an `br0` bridgen (NICHT `virbr0`/default-Netz: `br0` ist trusted + dnsmasq/DNS vorhanden), IP statisch außerhalb DHCP-Range (`10.8.0.100-.199`) + in `hosts/mireo/vm-ips.nix` eintragen. Die 7 microVMs (`microvm.nix`, `microvm@*`) erscheinen NICHT in virt-manager. Recovery bei `243/CREDENTIALS` (libvirt 12.4 secrets-encryption-key/TPM-Bug): `rm /var/lib/libvirt/secrets/secrets-encryption-key` + reboot.

## Config files

- `data/hosts/mireo/settings.nix` — network, NAT, dnsmasq, NFS, Avahi, Netdata, nixfleet
- `hosts/mireo/host.nix` — applyHost
- `hosts/mireo/*-microvm.nix` (7) + `microvm-base.nix` + `vm-ips.nix` (shared static IP map)
- QEMU tap→br0 (`flake.nix:193`)

## VMs at a glance

| VM | IP | RAM | vCPU |
|----|----|-----|------|
| grafana | 10.8.0.2 | 768M | 2 |
| network-services | 10.8.0.3 | 384M | 1 |
| monerod | 10.8.0.4 | 2304M | 2 |
| yammat | 10.8.0.5 | 2304M | 2 |
| cups | 10.8.0.6 | 512M | 1 |
| sshkeys | 10.8.0.7 | 256M | 1 |
| aptcache | 10.8.0.8 | 512M | 1 |

→ [[10-Hosts/MicroVMs|MicroVM details]], Monero 9001/tcp WAN→VM forwarding.

## Deploy

```bash
nix run .#deploy-mireo
deploy .#mireo
```
