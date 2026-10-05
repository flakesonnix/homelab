# Hosts

## Network Layout

```
Internet (IPv4 + IPv6 via FritzBox)
    │
    │ 192.168.178.25 / 2a02:3102:4c00:3b::1b5/64 (WAN)
  mireo (router)
    │
    │ 10.8.0.1/24 + fd00:cafe:1::1/64 (br0)
    ├── 10.8.0.2  grafana microvm     (Prometheus + Grafana)
    ├── 10.8.0.3  network-services vm (bridge stub)
    ├── 10.8.0.4  monerod microvm     (Monero node + Tor relay)
    ├── 10.8.0.5  yammat microvm      (YAMMAT event management)
    ├── 10.8.0.6  cups microvm        (CUPS print server)
    ├── 10.8.0.7  sshkeys microvm     (SSH public key web)
    ├── 10.8.0.9  uptime-kuma microvm (status monitoring :3001)
    ├── 10.8.0.10 jellyfin microvm    (media server :8096)
    ├── 10.8.0.11 ntp microvm         (chrony NTP :123/udp)
    ├── 10.8.0.12 lldap microvm       (LDAP directory)
    ├── 10.8.0.13 pocket-id microvm   (OIDC provider)
    ├── 10.8.0.14 cloud microvm       (Nextcloud, stub)
    ├── 10.8.0.15 management microvm  (NetBox + LibreNMS, stub)
    ├── 10.8.0.16 —                   (reserved: librenms, unassigned)
    ├── 10.8.0.17 devops microvm       (Hydra + Woodpecker CI, stub)
    ├── 10.8.0.18 —                   (reserved: hydra, unassigned)
    ├── 10.8.0.19 —                   (reserved: registry, unassigned)
    ├── 10.8.0.20 artifacts microvm   (Attic cache + OCI registry)
    ├── 10.8.0.21 media microvm       (Immich, stub)
    ├── 10.8.0.22 documents microvm   (Paperless, stub)
    ├── 10.8.0.23 communication microvm (Matrix + ntfy)
    ├── 10.8.0.24 —                   (reserved: ntfy, unassigned)
    ├── 10.8.0.25 remote microvm       (RustDesk relay)
    ├── 10.8.0.26 sync microvm        (Syncthing, stub)
    ├── 10.8.0.27 maps microvm        (OSM tiles)
    ├── 10.8.0.28 postgres microvm    (PostgreSQL platform, stub)
    ├── 10.8.0.29 identity microvm    (OpenLDAP + Keycloak, stub)
    ├── 10.8.0.30 dns microvm         (AdGuard Home filtering :53/:3000)
    ├── 10.8.0.32 dash microvm        (Homepage dashboard :8082)
    ├── 10.8.0.193 ff-bb              (Freifunk box, DHCP reservation)
    └── (DHCP)      x270 (dynamic, see below)
```

mireo bridges microvms onto br0 via tap interfaces. NAT masquerade on `enp4s0` (WAN). IPv6 prefix `2a02:3102:4cec:b500::/64` delegated from FritzBox to br0; dnsmasq issues RA + SLAAC (constructor:br0) to LAN clients and assigns addresses via DHCPv6 (stateful ULA range). LAN clients (x270 etc.) get fully dynamic addresses; only the 10 microVMs and mireo itself have static IPs + DNS records.

---

## x270

**Role:** Primary desktop / gaming laptop  
**Hardware:** Lenovo ThinkPad X270, i7-7600U  
**IP:** dynamic via DHCP (dnsmasq on mireo; reachable by hostname)

### Features
- Niri Wayland compositor with eww desktop shell (topbar + sidebar)
- Stylix theming (cyberdeck/dark palette)
- Secure Boot via lanzaboote
- Suspend-then-hibernate (lid close, 30 min timer on battery)
- Smartcard reader (pcscd + ccid)
- Gaming: Steam, GameMode, Gamescope (capSysNice), MangoHud, performance governor
- Asterisk SIP PBX
- Audio streaming → remote tunnel sink
- Tailscale, Bluetooth
- Waydroid (Android container, initialised with GAPPS image via oneshot service)

### Roles
`desktop`, `dev`, `gaming`

### Config files
- `data/hosts/x270/settings.nix` — hostname, hosts, Bluetooth, Niri users, boot params
- `data/hosts/x270/module-flags.nix` — NixOS feature toggles (smartcard, fonts, waydroid, etc.)
- `data/hosts/x270/roles.nix` — role list
- `hosts/x270/host.nix` — framework applyHost call
- `hosts/x270/hardware-configuration.nix` — nixos-hardware-generated

### Special modules loaded
`asterisk`, `audio-stream`, `deskflow`, `fonts`, `gaming`, `gnome`, `gnome-extensions`, `niri`, `serial-getty`, `sops`, `waybar`, `waydroid`, `lanzaboote`

### Workarounds
- `virtualisation.libvirtd.enable = mkForce false` in `data/hosts/x270/settings.nix` — recent NixOS `libvirt 12.4.0` tries `Tss2_Tcti_Device_Init(/dev/tpmrm0)` and fails `243/CREDENTIALS` when no TPM device exists, causing `nixos-rebuild-ng` (now strict, exits 4 on any failed unit) to abort the switch. Local daemon off, `programs.virt-manager` client stays on for remote `qemu+ssh://root@10.8.0.1/system` (mireo).

### Deploy

```bash
# Local (preferred, via nh)
nix run .#rebuild
# or
sudo nixos-rebuild switch --flake .#x270

# Via deploy-rs (to localhost, or x270's current DHCP address/hostname when deploying remotely)
nix run .#deploy-x270   # SSH to localhost as root
deploy .#x270           # same, via deploy-rs directly

# Deploy from x270 to mireo (LAN)
nix run .#deploy-mireo  # SSH to 10.8.0.1
```



## mireo

**Role:** Home server and LAN router  
**Hardware:** Mini-PC with 4-port NIC (enp4s0 WAN, enp9s0/enp3s0f0/enp3s0f1 bridged to br0)  
**IP:** 10.8.0.1 (LAN), 192.168.178.25 (WAN)

### Features
- NAT gateway for 10.8.0.0/24 + IPv6 (FritzBox DHCPv6-PD, prefix `2a02:3102:4cec:b500::/64`)
- systemd-networkd (no NetworkManager)
- dnsmasq on host: DHCPv4, stateful DHCPv6 (explicit ULA range), DNS, IPv6 RA/SLAAC (constructor:br0) for LAN (br0), authoritative home.arpa zone (SOA/NS via auth-zone)
- PXE boot via dnsmasq (iPXE binaries from nixpkgs, netboot.xyz menu over HTTP)
- NFS export of `/data` to `10.8.0.0/24`
- Avahi mDNS advertising NFS share (`_nfs._tcp`) for Nautilus autodiscovery
- Metrics via Grafana/Prometheus + uptime-kuma alerting + nixfleet agent (netdata dropped 2026-09-16)
- Caddy reverse proxy on `:80` — every web UI as `http://<name>.home.arpa` (grafana, prometheus, yammat, cups, sshkeys, uptime-kuma, jellyfin, lldap, pocket-id, dash, adguard, music) + `http://status.home.arpa` (302 → Uptime Kuma status page)
- Mopidy music server on the host (no VM): `/data/Jellyfin/Music` + Jellyfin backend to the USB mixer (Behringer Xenyx 302USB) via ALSA; clients M.A.L.P./mpc + Iris web UI via `music.home.arpa`
- AdGuard Home (dns VM) as filtering-only DNS frontend (blocklists); dnsmasq on the host stays authoritative for DHCP + LAN DNS (advertises `.30` first, `.1` fallback)
- 26 microVMs running on br0 (single `mk-microvm.nix` spec pattern, stable per-VM SSH host keys):
  - **grafana** (10.8.0.2): Prometheus scraping router + all hosts, Grafana with mireo-router dashboard
  - **network-services** (10.8.0.3): bridge tap stub (no services)
  - **monerod** (10.8.0.4): Pruned Monero node + Tor relay (nickname `mireoMoneroRelay`)
  - **yammat** (10.8.0.5): YAMMAT event management (C3D2 matemat, port 3000)
  - **cups** (10.8.0.6): CUPS print server (IPP, Avahi, Epson ET-2860 + Lexmark)
  - **sshkeys** (10.8.0.7): Nginx serving SSH public keys
  - **uptime-kuma** (10.8.0.9): Uptime Kuma status monitoring (port 3001, via `http://uptime-kuma.home.arpa`)
  - **jellyfin** (10.8.0.10): Jellyfin media server (port 8096, via `http://jellyfin.home.arpa`)
  - **ntp** (10.8.0.11): chrony NTP server (UDP 123, via DHCP option 42)
  - **lldap** (10.8.0.12): LDAP directory (`dc=home,dc=arpa`, :3890 + UI :17170 via `http://lldap.home.arpa`)
  - **pocket-id** (10.8.0.13): OIDC provider
  - **cloud** (10.8.0.14): Nextcloud (stub)
  - **management** (10.8.0.15): NetBox + LibreNMS (stub)
  - **devops** (10.8.0.17): Hydra + Woodpecker CI (stub)
  - **artifacts** (10.8.0.20): Attic binary cache + OCI registry
  - **media** (10.8.0.21): Immich (stub)
  - **documents** (10.8.0.22): Paperless (stub)
  - **communication** (10.8.0.23): Matrix Synapse + ntfy
  - **remote** (10.8.0.25): RustDesk relay
  - **sync** (10.8.0.26): Syncthing (stub)
  - **maps** (10.8.0.27): OSM tiles (:80)
  - **postgres** (10.8.0.28): PostgreSQL platform (stub)
  - **identity** (10.8.0.29): OpenLDAP + Keycloak (stub)
  - **dns** (10.8.0.30): AdGuard Home filtering (:53/:3000, via `http://adguard.home.arpa`)
  - **dash** (10.8.0.32): Homepage dashboard (:8082, via `http://dash.home.arpa`)
  - (retired: **aptcache** 10.8.0.8 decommissioned 2026-10-05, **kodi** music-box replaced by Mopidy)
- No desktop (`lucy.base.isServer = true`)
- node_exporter running on 10.8.0.1:9100 for self-monitoring
- libvirtd daemon for virt-manager remote (Weg A): x270 connects via `qemu+ssh://root@10.8.0.1/system`, new libvirt guests bridge to `br0` (`allowedBridges`), static IP outside DHCP range + entry in `hosts/mireo/vm-ips.nix`. The 26 microVMs (microvm.nix) do NOT show in virt-manager. Recovery on `243/CREDENTIALS`: `rm /var/lib/libvirt/secrets/secrets-encryption-key` + reboot.
- CLI tools: tcpdump, mtr, nmap, iperf3, ethtool, socat, btop, htop, ncdu, jq, lsof, sysstat, smartmontools

### NixFleet (M1 — mireo runtime control plane)
- `lucy.nixfleet.enable = true; role = "api"` in `data/hosts/mireo/settings.nix` — both `nixfleet-api` (8443, `DynamicUser`, `StateDirectory=nixfleet`) and `nixfleet-agent` (`systemd`+`journal`+`metrics`) run on mireo; module no longer gates on `role`, so `api` host also runs agent.
- `api.artifactsDir = ../../../nixfleet/artifacts` (committed `manifest.json`/`ui.json`), `api.webDir` via `flake.nix` `nixfleetPkgs.web` when built; firewall `br0` now allows `8443`.
- **M1 API (DONE, 7a05039, Sep 2026)**: `GET /api/v1/hosts`, `/:host/health` (`healthy|degraded|critical|unknown`, `failedUnits`), `/:host/resources` (`/proc`), `/:host/network` (`ip -j`), `/:host/vms` (merged `configured` from manifest + `runtime` via `systemctl is-active microvm@<name>` validated), `/:host/systemd/failed` — typed Go structs, `404` for unknown host/vm, `503` for non-local host (M1 collects only where API runs).
- **Frontend**: `HostOverview` + `VMTable` + `SystemdFailed` on dashboard; `/vms` lists 10 VMs (grafana…ntp) with `Name|IP|State|vCPU|RAM|Health|Ports`, network table shows `br0` + VM taps. Dark dense monospace styling.
- No WebSocket/auth/SQLite yet — observability first. M1-full will add agent WS protocol + full multi-host support.

### Roles
None (server profile, framework data in `data/hosts/mireo/` — `roles.nix` intentionally absent, manifest `roles: []`)

### Config files
- `data/hosts/mireo/settings.nix` — hostname, network, NAT, dnsmasq (+native PXE/netboot.xyz), NFS, Avahi, Netdata, **nixfleet M1** (`lucy.nixfleet.*`, firewall 8443)
- `hosts/mireo/host.nix` — framework applyHost
- `hosts/mireo/vm-ips.nix` — static IP map shared by VM specs, DNS and proxy; handed out via dnsmasq `dhcp-host` reservations (guests use DHCPv4, ULA stays static)
- `hosts/mireo/grafana-microvm.nix` — grafana + prometheus microvm
- `hosts/mireo/monerod-microvm.nix` — monerod + Tor microvm
- `hosts/mireo/network-services-microvm.nix` — network-services bridge tap stub
- `hosts/mireo/yammat-microvm.nix` — YAMMAT microvm
- `hosts/mireo/cups-microvm.nix` — CUPS print server microvm
- `hosts/mireo/sshkeys-microvm.nix` — SSH public key web server microvm
- `hosts/mireo/mk-microvm.nix` — typed microVM spec builder (all VMs use it)
- `hosts/mireo/microvm-base.nix` — shared microvm base config (virtiofs shares, stable per-VM SSH host keys)

### Microvm resource allocation
| VM | IP | Memory | vCPUs | Storage |
|----|-----|--------|-------|---------|
| grafana | 10.8.0.2 | 768 MB | 2 | 1 GB grafana + 1 GB prometheus |
| network-services | 10.8.0.3 | 384 MB | 1 | — |
| monerod | 10.8.0.4 | 2304 MB | 2 | 350 GB blockchain |
| yammat | 10.8.0.5 | 2304 MB | 2 | 8 GB postgres + 128 MB state |
| cups | 10.8.0.6 | 512 MB | 1 | 256 MB cups config |
| sshkeys | 10.8.0.7 | 256 MB | 1 | — |
| uptime-kuma | 10.8.0.9 | 512 MB | 1 | 1 GB state (SQLite) |
| jellyfin | 10.8.0.10 | 2304 MB | 2 | 8 GB state + 4 GB transcode cache |
| ntp | 10.8.0.11 | 256 MB | 1 | — (stateless, drift re-learns) |
| lldap | 10.8.0.12 | 512 MB | 1 | 512 MB state |
| pocket-id | 10.8.0.13 | 512 MB | 1 | 512 MB state |
| cloud | 10.8.0.14 | 2304 MB | 4 | 8 GB state |
| management | 10.8.0.15 | 1024 MB | 2 | 1 GB netbox + 1 GB librenms |
| devops | 10.8.0.17 | 2048 MB | 4 | 1 GB woodpecker + 2 GB hydra |
| artifacts | 10.8.0.20 | 1024 MB | 2 | 4 GB attic + 4 GB registry |
| media | 10.8.0.21 | 4096 MB | 4 | 8 GB state |
| documents | 10.8.0.22 | 1024 MB | 2 | 2 GB state |
| communication | 10.8.0.23 | 2304 MB | 2 | 4 GB matrix + 1 GB ntfy |
| remote | 10.8.0.25 | 512 MB | 1 | 512 MB state |
| sync | 10.8.0.26 | 512 MB | 1 | 2 GB state |
| maps | 10.8.0.27 | 8192 MB | 4 | OSM planet + tiles images |
| postgres | 10.8.0.28 | 2304 MB | 4 | 8 GB data |
| identity | 10.8.0.29 | 1024 MB | 2 | 2 GB ldap + 2 GB keycloak |
| dns | 10.8.0.30 | 384 MB | 1 | 512 MB AdGuard data |
| dash | 10.8.0.32 | 1024 MB | 1 | 512 MB state |

### Monero port forwarding
Port 9001/tcp (Tor ORPort) forwarded from WAN to monerod VM.

### Deploy
```bash
nix run .#deploy-mireo   # SSH to mireo via deploy-rs (10.8.0.1 on LAN, 192.168.178.25 from FritzBox LAN)
deploy .#mireo           # same, via deploy-rs directly
```


## nyagate

**Role:** Remote server (QEMU VM, external hosting)
**Host:** db210.org
**IP:** 188.220.148.24/32 (eth0, gateway 10.0.0.1)

### Features
- Minimal server profile (`lucy.base.isServer = true`, no desktop/home-manager)
- Static IPv4 + GRUB on /dev/vda (BIOS, QEMU guest profile)
- OpenSSH, user `lucy` (wheel/sudo) + shared repo SSH key (also authorizes root, key-only)
- stateVersion 26.11 (matches initial install)

### Config files
- `data/hosts/nyagate/settings.nix` — hostname, static network, GRUB, SSH, topology
- `data/hosts/nyagate/packages.nix` — server CLI tools (mirrors mireo)
- `hosts/nyagate/host.nix` — framework applyHost
- `hosts/nyagate/hardware-configuration.nix` — imported from on-host `nixos-generate-config`

### Deploy
```bash
nix run .#deploy-nyagate  # SSH to db210.org as lucy, sudo to root via deploy-rs
deploy .#nyagate          # same, via deploy-rs directly
```

