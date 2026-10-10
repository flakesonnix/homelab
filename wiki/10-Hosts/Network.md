---
aliases: [Network, LAN, Topology-Net]
tags: [network, host, reference]
type: reference
---

# Network

[[10-Hosts/Hosts-MOC|← Hosts]] · SVG: `nix build .#topology`

```
Internet (v4+v6 via FritzBox)
  │ 192.168.178.25 / 2a02:3102:4c00:3b::1b5/64 WAN
mireo (router)
  │ 10.8.0.1/24 + fd00:cafe:1::1/64 br0
  ├── 10.8.0.2  grafana
  ├── 10.8.0.3  network-services
  ├── 10.8.0.4  monerod (9001/tcp WAN forward, Tor ORPort)
  ├── 10.8.0.5  yammat :3000
  ├── 10.8.0.6  cups :631
  ├── 10.8.0.7  sshkeys :80
  ├── 10.8.0.9  uptime-kuma :3001 (via Caddy uptime-kuma.home.arpa)
  ├── 10.8.0.10 jellyfin :8096 (via Caddy jellyfin.home.arpa)
  ├── 10.8.0.11 ntp :123/udp (via DHCP option 42)
  ├── 10.8.0.12 lldap :3890 + :17170 (UI via Caddy lldap.home.arpa)
  └── (DHCP)      p53 (dynamic address via DHCPv4/DHCPv6)
```

All VM IPs are **dnsmasq DHCP reservations** (`dhcp-host` from `hosts/mireo/vm-ips.nix`, MAC `02:00:00:10:08:XX` derived from IP) — same addresses as before, but centrally handed out instead of on-guest statics (guests run `DHCP=ipv4`, ULA stays static). Plus one real-hardware reservation: `ff-bb` (Freifunk box, MAC `44:d4:37:8b:d8:69` → 10.8.0.193, named so because its own hostname collides with ours). DHCP advertises DNS `.30` (AdGuard filter) first, host `.1` fallback. DNS comes from both the lease name and `host-record` (A + AAAA mirror).

- NAT masquerade on `enp4s0`, br0 from enp9s0/enp3s0f0/enp3s0f1; NAT66 outbound (LAN ULA → WAN SLAAC-GUA, `nftables.nat66`, prefix-change-proof) — primärer v6-Egress, VPS-unabhängig (HE-Tunnel entfernt 2026-10-10)
- IPv6: FritzBox (6660 Cable) gibt mireo WAN per SLAAC (Präfix wechselt bei Reconnects); DHCPv6 (IA_NA+PD) bleibt unbeantwortet (kein Lease) — Hausaufgabe FritzBox-UI: DHCPv6-Server + Präfix-Delegation an (braucht ISP-Präfix kürzer als /64). Landet PD, bekommt br0 automatisch ein GUA-/64 (networkd) und dnsmasq kündigt es per RA an (`constructor:br0`), ohne Deploy. Bis dahin: ULA-only LAN + NAT66.
- dnsmasq host records = VM names, `bindsTo sys-devices-virtual-net-br0.device` fix; fixed IPs via `dhcp-host` reservations (not on-guest statics)
- NFS `/data` → 10.8.0.0/24, Avahi `_nfs._tcp`, Nautilus autodiscovery
- PXE boot via dnsmasq (iPXE from nixpkgs via TFTP) + Caddy file server `/boot` from `/data/pxe`: local iPXE menu (`http://10.8.0.1/boot/menu.ipxe`) with NixOS GNOME desktop as default, netboot.xyz as fallback. Payload: `nix build .#pxe-desktop-boot` (`just pxe-boot`, source `hosts/pxe-desktop/`), files to mireo `/data/pxe` syncen. iVentoy removed Sep 2026.
- Printing: IPP + Avahi `_ipp._tcp` (10.8.0.6)
- Reverse proxy: Caddy on mireo `:80` → `http://<name>.home.arpa` per web UI (grafana, prometheus, yammat, cups, sshkeys, uptime-kuma, jellyfin, lldap, pocket-id, dash, adguard, music) + `status.home.arpa` redir — details [[10-Hosts/mireo|mireo]]
- Tailscale on p53, Deskflow keyboard/mouse sharing

## dnsmasq / IP cheat sheet

```bash
cat data/hosts/mireo/settings.nix | grep -A2 dnsmasq -n | head
ip -j addr | jq
ss -tulpn
```

Topology extras: `topology.nix` (NFS, YAMMAT, CUPS, sshkeys, monerod manual entries, mireo=router).

## Transit / WireGuard (sops)

Network `10.66.0.0/30` mireo .2 ↔ nyagate .1 (`db210.org`, public edge: DNAT 80/443/25565 → tunnel, v4) — private keys only in sops, details [[40-Guides/Secrets-Guide|Secrets guide]]. v6 läuft NICHT mehr über den Tunnel (HE entfernt 2026-10-10): LAN-v6 geht nativ via FritzBox (NAT66/PD), nyagates eigener v6-Uplink bleibt dessen HE-Tunnel.
