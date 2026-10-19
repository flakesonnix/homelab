---
aliases: [mireo, Router, Homeserver]
tags: [host, nixos, network, nixfleet, server]
type: host
host: mireo
ip: 10.8.0.1
wan: 192.168.178.25
role: Homeserver / LAN router + 18 microVMs (8 Stubs deaktiviert)
roles: []
deploy: nix run .#deploy-mireo
---

# mireo

> [!info] Profile
> **Role:** router/server · **LAN:** `10.8.0.1/24` + `fd00:cafe:1::1/64` (br0) · **WAN:** `192.168.178.25`
> **Deploy:** `nix run .#deploy-mireo` · **NixFleet:** API+agent `:8443`

[[10-Hosts/Hosts-MOC|← Hosts]] · [[10-Hosts/MicroVMs|MicroVMs]] · [[10-Hosts/Network|Network]] · [[50-NixFleet/NixFleet-MOC|NixFleet]]

## Features

- NAT for 10.8.0.0/24 + natives IPv6 via FritzBox (WAN-SLAAC + NAT66 fürs ULA-LAN, PD angefragt/auto bei Delegation), systemd-networkd (HE-Tunnel über VPS entfernt 2026-10-10)
- dnsmasq: DHCPv4 (+ static reservations from `vm-ips.nix` for all services)/stateful DHCPv6 (explicit ULA range)/DNS/RA+SLAAC (constructor:br0) (`bindsTo sys-devices-virtual-net-br0.device` fix)
- PXE via Pixiecore: ProxyDHCP/TFTP auf `10.8.0.1`, Boot-HTTP auf `:8080`; dnsmasq bleibt für DHCP/DNS zuständig, Caddy auf `:80` unverändert. BIOS/UEFI laden iPXE und das festgelegte netboot.xyz-Menü `3.0.3`, ohne Bootloader-Austausch durch das Rolling-Menü. Das Startskript nutzt IPv4-DNS statt des fehlerhaften UEFI-IPv6-Pfads, HTTPS mit HTTP-Fallback. Kein `/data` oder eigener Installer-Build nötig; DNS/Internet erforderlich, Secure Boot aus. `just pxe-boot` bleibt für den optionalen eigenen NixOS-Installer.
- NFS export of `/data` → 10.8.0.0/24, Avahi `_nfs._tcp`, node_exporter :9100 (netdata dropped 2026-09-16)
- Mopidy music server (host ALSA → Behringer USB mixer): `/data/Jellyfin/Music` + Jellyfin backend, MPD `:6600`, Iris via `music.home.arpa` (replaced kodi VM Oct 2026)
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
| uptime-kuma.home.arpa | 10.8.0.9:3001 |
| jellyfin.home.arpa | 10.8.0.10:8096 |
| lldap.home.arpa | 10.8.0.12:17170 |
| media.home.arpa | alias → jellyfin (CNAME + VHost) |
| status.home.arpa | 302 → uptime-kuma.home.arpa/status/homelab |
| netdata.home.arpa | dropped 2026-09-16 (see Grafana/Prometheus) |

Source: `webUIs` map in `data/hosts/mireo/settings.nix` → `services.caddy.virtualHosts`.

## libvirt (virt-manager remote target, Weg A)

`virtualisation.libvirtd` in `data/hosts/mireo/settings.nix:112` (`enable=true`, `allowedBridges=["br0"]`, `qemu.vhostUserPackages=[virtiofsd]`) — p53 verbindet via `qemu+ssh://root@10.8.0.1/system`. Neue Gäste an `br0` bridgen (NICHT `virbr0`/default-Netz: `br0` ist trusted + dnsmasq/DNS vorhanden), IP statisch außerhalb DHCP-Range (`10.8.0.100-.199`) + in `hosts/mireo/vm-ips.nix` eintragen. Die 18 aktiven microVMs (`microvm.nix`, `microvm@*`; 8 Stubs in `hosts/mireo/default.nix` auskommentiert) erscheinen NICHT in virt-manager. Recovery bei `243/CREDENTIALS` (libvirt 12.4 secrets-encryption-key/TPM-Bug): `rm /var/lib/libvirt/secrets/secrets-encryption-key` + reboot.

## Config files

- `data/hosts/mireo/settings.nix` — network, NAT, dnsmasq, NFS, Avahi, nixfleet
- `hosts/mireo/host.nix` — applyHost
- `hosts/mireo/*-microvm.nix` (7) + `microvm-base.nix` + `vm-ips.nix` (shared static IP map, handed out via dnsmasq `dhcp-host` reservations)
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

→ [[10-Hosts/MicroVMs|MicroVM details]], Monero 9001/tcp WAN→VM forwarding.

## Deploy

```bash
nix run .#deploy-mireo
deploy .#mireo
```
