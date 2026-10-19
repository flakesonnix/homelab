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
    ├── 10.8.0.31 fxsync microvm      (Sync backend :5000, mireo only)
    ├── 10.8.0.32 dash microvm        (Homepage dashboard :8082)
    ├── 10.8.0.193 ff-bb              (Freifunk box, DHCP reservation)
    └── (DHCP)      p53 (dynamic, see below)
```

mireo bridges microvms onto br0 via tap interfaces. NAT masquerade on `enp4s0` (WAN). IPv6 nativ via FritzBox (WAN-SLAAC, LAN per ULA+NAT66; PD angefragt — bei Delegation kündigt dnsmasq das GUA per RA/SLAAC via constructor:br0 automatisch an); dnsmasq assigns addresses via DHCPv6 (stateful ULA range). LAN clients (p53 etc.) get fully dynamic addresses; the microVMs and mireo itself have static IPs + DNS records (teils als dhcp-host-Reservierungen).

---

## p53

**Role:** Primary desktop / gaming laptop  
**Hardware:** Lenovo ThinkPad P53, i7-9750H  
**IP:** dynamic via DHCP (dnsmasq on mireo; reachable by hostname)

### Features
- GNOME with GDM, plus an optional SwayFX session (Swaybar, Fuzzel, Mako)
- Stylix theming (cyberdeck/dark palette)
- Secure Boot via lanzaboote
- Suspend-then-hibernate (lid close, 30 min timer on battery)
- Smartcard reader (pcscd + ccid), fingerprint reader (fprintd + PAM/GDM)
- Gaming: Steam, GameMode, Gamescope (capSysNice), MangoHud, performance governor
- Asterisk SIP PBX
- Audio streaming → remote tunnel sink
- Tailscale, Bluetooth
- Waydroid (Android container, initialised with GAPPS image via oneshot service)

### Roles
`desktop`, `dev`, `gaming`

### Config files
- `data/hosts/p53/settings.nix` — hostname, hosts, Bluetooth, Niri users, boot params
- `data/hosts/p53/module-flags.nix` — NixOS feature toggles (smartcard, fonts, waydroid, etc.)
- `data/hosts/p53/roles.nix` — role list
- `hosts/p53/host.nix` — framework applyHost call
- `hosts/p53/hardware-configuration.nix` — nixos-hardware-generated

### Special modules loaded
`asterisk`, `audio-stream`, `deskflow`, `fonts`, `gaming`, `gnome`, `gnome-extensions`, `niri`, `serial-getty`, `sops`, `waybar`, `waydroid`, `lanzaboote`

### SwayFX alongside GNOME

After rebuilding, log out, select your user in GDM, and choose **Sway** from the
session menu before logging in. This session runs SwayFX; GNOME remains available.
SwayFX uses the Intel GPU without changing GNOME's or NVIDIA offload's settings.
Outputs wired exclusively to NVIDIA need separate testing.

- `Super` as modifier with the Niri bind layout (Sway workspaces `1`–`9` on `Super+1`…`Super+9`)
- `Super+Enter`: Alacritty; `Super+D`: Fuzzel; `Super+W`: close
- `Super+H/J/K/L` or arrows: focus; add `Ctrl` to move; `Super+Shift+Arrows`: across outputs
- `Super+1`…`Super+9`: workspaces; `Super+Ctrl+1`…`Super+9` / `Super+Shift+1`…`Super+9`: move window there
- `Super+U/I` or `Super+PgUp/PgDn`: previous/next workspace; scrolled with `Super+Wheel`
- `Super+V`: floating toggle; `Super+Shift+V`: focus floating/tiling; `Super+Shift+F`: fullscreen
- `Super+Minus/Equal`: resize width; add `Shift` for height
- `Print` / `Super+Shift+S`: area shot; `Ctrl+Print`: screen; `Super+Print`: window (files like Niri under `~/Pictures/Screenshots`)
- `Super+Ctrl+Escape`: lock; `Super+Shift+C`: reload; `Super+Shift+E`: log out
- Lock after 5 minutes idle and before suspend; turn displays off after 10 minutes
- Cyberdeck colors with blur and shadows but square corners; the existing Niri-only Waybar stays disabled
- Niri-only actions without Sway equivalent: overview, column consume/expel, preset widths/heights, maximize-column (`Super+F` unbound), workspace moving, shortcut-inhibit toggle

### EWM alongside GNOME and SwayFX

[EWM](https://codeberg.org/ezemtsov/ewm) (Emacs Wayland Manager) is a Smithay-based Wayland compositor that runs as a dynamic module inside Emacs; Wayland windows become Emacs buffers. After rebuilding, choose **ewm** from the GDM session menu. It is pinned via the `ewm` flake input (`modules/nixos/ewm.nix`, `programs.ewm`), currently without the Skia GPU-Emacs variant.

- Requires your own Emacs init (`~/.emacs.d` or `~/.config/emacs`); see the [EWM wiki](https://codeberg.org/ezemtsov/ewm/wiki) for keybindings and configuration. Launch apps with `s-d`.
- Must run from its GDM session (no nested mode); GPU selection is automatic.
- `wl-clipboard` and `brightnessctl` are installed system-wide for clipboard and media keys; PipeWire screen sharing stays enabled.
- `Super+L`, five minutes idle, and suspend use the same session-scoped locker; suspend waits for the compositor to acknowledge the lock.

### Local virtualisation (virt-manager)

- `virtualisation.libvirtd` in `data/hosts/p53/settings.nix` (`enable=true`, `qemu.swtpm.enable=true` für TPM-Emulation in Gästen) — lokaler Daemon an (`/dev/tpmrm0` vorhanden; alter libvirt-12.4-`243/CREDENTIALS`-Workaround mit `mkForce false` obsolet). `programs.virt-manager` zeigt lokal (`qemu:///system`, autoconnect) + remote mireo (`qemu+ssh://root@10.8.0.1/system`). Recovery bei `243/CREDENTIALS`: `rm /var/lib/libvirt/secrets/secrets-encryption-key` + reboot.

### Deploy

```bash
# Local (preferred, via nh)
nix run .#rebuild
# or
sudo nixos-rebuild switch --flake .#p53

# Via deploy-rs (to localhost, or p53's current DHCP address/hostname when deploying remotely)
nix run .#deploy-p53   # SSH to localhost as root
deploy .#p53           # same, via deploy-rs directly

# Deploy from p53 to mireo (LAN)
nix run .#deploy-mireo  # SSH to 10.8.0.1
```



## mireo

**Role:** Home server and LAN router  
**Hardware:** Mini-PC with 4-port NIC (enp4s0 WAN, enp9s0/enp3s0f0/enp3s0f1 bridged to br0)  
**IP:** 10.8.0.1 (LAN), 192.168.178.25 (WAN)

### Features
- NAT gateway for 10.8.0.0/24 + native IPv6 via FritzBox (WAN-SLAAC + NAT66 fürs ULA-LAN; PD angefragt — landet ein Präfix, gehts nativ raus. HE-Tunnel über VPS entfernt 2026-10-10)
- systemd-networkd (no NetworkManager)
- dnsmasq on host: DHCPv4 (+NTP option 42 → ntp VM .11), stateful DHCPv6 (explicit ULA range), DNS, IPv6 RA/SLAAC (constructor:br0) for LAN (br0), `home.arpa` kept strictly local.
- PXE boot via Pixiecore ProxyDHCP/TFTP on `10.8.0.1`, alongside dnsmasq's unchanged DHCP/DNS. Boot HTTP uses `:8080`, leaving Caddy on `:80`. BIOS and UEFI receive iPXE plus a store-backed bootstrap pinned to the netboot.xyz `3.0.3` menu, avoiding the rolling menu's bootloader replacement. The bootstrap uses IPv4 DNS (UEFI's IPv6 path is unreliable), with HTTPS preferred and HTTP fallback for loaders without HTTPS. No `/data`, payload sync or custom installer build required. Clients need DNS/Internet access and Secure Boot disabled. `pxe-desktop-boot` remains an optional custom installer, not the default boot path.
- NFS export of `/data` to `10.8.0.0/24`
- `/data` is optional at boot, with a 10-second missing-device timeout. NFS, Jellyfin, Mopidy and Asterisk/fax require the mounted disk; SSH, DHCP/DNS and unrelated VMs remain available. Directory setup never writes a fallback tree on the root filesystem. After reconnecting the disk, mount `/data` and explicitly start its consumers.
- Avahi mDNS advertising NFS share (`_nfs._tcp`) for Nautilus autodiscovery
- Metrics via Grafana/Prometheus + uptime-kuma alerting + nixfleet agent (netdata dropped 2026-09-16)
- Caddy reverse proxy on `:80` — every web UI as `http://<name>.home.arpa` (grafana, prometheus, yammat, cups, sshkeys, uptime-kuma, jellyfin, lldap, pocket-id, dash, adguard, music) + `http://status.home.arpa` (302 → Uptime Kuma status page)
- Mopidy music server on the host (no VM): `/data/Jellyfin/Music` + Jellyfin backend to the USB mixer (Behringer Xenyx 302USB) via ALSA; clients M.A.L.P./mpc + Iris web UI via `music.home.arpa`
- AdGuard Home (dns VM) as filtering-only DNS frontend (blocklists); dnsmasq on the host stays authoritative for DHCP + LAN DNS (advertises `.30` first, `.1` fallback)
- 18 microVMs running on br0 (single `mk-microvm.nix` spec pattern, stable per-VM SSH host keys; 8 weitere Stub-VMs sind in `hosts/mireo/default.nix` auskommentiert — IPs/DNS in `vm-ips.nix` bleiben reserviert):
  - **grafana** (10.8.0.2): Prometheus scraping router + all hosts, Grafana with mireo-router dashboard
  - **network-services** (10.8.0.3): reserved stub (no services; host dnsmasq provides DHCP/DNS, Pixiecore provides PXE)
  - **monerod** (10.8.0.4): Pruned Monero node + Tor relay (nickname `mireoMoneroRelay`)
  - **yammat** (10.8.0.5): YAMMAT event management (C3D2 matemat, port 3000)
  - **cups** (10.8.0.6): CUPS print server (IPP, Avahi, Epson ET-2860 + Lexmark)
  - **sshkeys** (10.8.0.7): Nginx serving SSH public keys
  - **uptime-kuma** (10.8.0.9): Uptime Kuma status monitoring (port 3001, via `http://uptime-kuma.home.arpa`)
  - **jellyfin** (10.8.0.10): Jellyfin media server (port 8096, via `http://jellyfin.home.arpa`)
  - **ntp** (10.8.0.11): chrony NTP server (UDP 123, via DHCP option 42)
  - **lldap** (10.8.0.12): LDAP directory (`dc=home,dc=arpa`, :3890 + UI :17170 via `http://lldap.home.arpa`)
  - **pocket-id** (10.8.0.13): OIDC provider
  - **artifacts** (10.8.0.20): Attic binary cache + OCI registry
  - **communication** (10.8.0.23): Matrix Synapse + ntfy
  - **remote** (10.8.0.25): RustDesk relay
  - **maps** (10.8.0.27): OSM tiles (:80)
  - **dns** (10.8.0.30): AdGuard Home filtering (:53/:3000, via `http://adguard.home.arpa`)
  - **fxsync** (10.8.0.31): Firefox Sync storage (syncstorage-rs single-node :5000, mireo-only backend; clients use `https://fxsync.home.arpa` on mireo)
  - **dash** (10.8.0.32): Homepage dashboard (:8082, via `http://dash.home.arpa`)
  - (deaktiviert, nur reservierte IPs/DNS: **cloud** .14 Nextcloud, **management** .15 NetBox+LibreNMS, **devops** .17 Hydra+Woodpecker, **media** .21 Immich, **documents** .22 Paperless, **sync** .26 Syncthing, **postgres** .28 PostgreSQL, **identity** .29 OpenLDAP+Keycloak)
  - (retired: **aptcache** 10.8.0.8 decommissioned 2026-10-05, **kodi** music-box replaced by Mopidy)
- No desktop (`lucy.base.isServer = true`)
- node_exporter running on 10.8.0.1:9100 for self-monitoring
- libvirtd daemon for virt-manager remote (Weg A): p53 connects via `qemu+ssh://root@10.8.0.1/system`, new libvirt guests bridge to `br0` (`allowedBridges`), static IP outside DHCP range + entry in `hosts/mireo/vm-ips.nix`. The 18 active microVMs (microvm.nix) do NOT show in virt-manager. Recovery on `243/CREDENTIALS`: `rm /var/lib/libvirt/secrets/secrets-encryption-key` + reboot.
- CLI tools: tcpdump, mtr, nmap, iperf3, ethtool, socat, btop, htop, ncdu, jq, lsof, sysstat, smartmontools

### Firefox Sync enrollment

Sync is opt-in: this configuration does not change Firefox profiles or migrate
existing Mozilla-hosted Sync data. Mozilla still provides the account; only
storage and Sync token issuance are self-hosted. Both LAN resolvers point
`fxsync.home.arpa` at mireo's Caddy, not the backend VM. Caddy uses `tls internal`
(no public ACME) and permits only loopback, `10.8.0.0/24`, and
`fd00:cafe:1::/64`; other source addresses receive HTTP 403 over HTTPS.

1. After an explicitly authorized deployment, obtain only Caddy's **public root
   CA certificate** over authenticated SSH from
   `/var/lib/caddy/.local/share/caddy/pki/authorities/local/root.crt` on mireo.
   Verify its fingerprint over that trusted channel; keep the public certificate
   client-local, not in this repository. Import it into Firefox's
   certificate Authorities with website trust, or a client trust store Firefox
   actually uses. Android must also trust this CA in the store used by that
   Firefox build; installing a user CA alone is not sufficient on every build.
2. Confirm `https://fxsync.home.arpa` has no certificate warning before enrolling.
   Never disable certificate verification or use an HTTP endpoint. Never copy or
   commit Caddy's private CA key (`root.key`) or its private CA directory.
3. Desktop: before signing in to Sync, set `identity.sync.tokenserver.uri` in
   `about:config` to `https://fxsync.home.arpa/1.0/sync/1.5`, restart Firefox,
   then sign in. A previously connected profile must disconnect first; changing
   this preference alone does not migrate it.
4. Android: disconnect the Mozilla account, tap the logo five times under
   Settings > About Firefox, then set **Sync Debug > Custom Sync Server** to the
   same HTTPS tokenserver URL. Restart and sign in only after CA trust works.

TCP/5000 is not a client endpoint: the guest firewall admits only mireo
(`10.8.0.1` / `fd00:cafe:1::1`). Guest SSH remains on `10.8.0.31:22`.

### NixFleet (M1 — mireo runtime control plane)
- `lucy.nixfleet.enable = true; role = "api"` in `data/hosts/mireo/settings.nix` — both `nixfleet-api` (8443, `DynamicUser`, `StateDirectory=nixfleet`) and `nixfleet-agent` (`systemd`+`journal`+`metrics`) run on mireo; module no longer gates on `role`, so `api` host also runs agent.
- `api.artifactsDir = ../../../nixfleet/artifacts` (committed `manifest.json`/`ui.json`), `api.webDir` via `flake.nix` `nixfleetPkgs.web` when built; firewall `br0` now allows `8443`.
- **M1 API (DONE, 7a05039, Sep 2026)**: `GET /api/v1/hosts`, `/:host/health` (`healthy|degraded|critical|unknown`, `failedUnits`), `/:host/resources` (`/proc`), `/:host/network` (`ip -j`), `/:host/vms` (merged `configured` from manifest + `runtime` via `systemctl is-active microvm@<name>` validated), `/:host/systemd/failed` — typed Go structs, `404` for unknown host/vm, `503` for non-local host (M1 collects only where API runs).
- **Frontend**: `HostOverview` + `VMTable` + `SystemdFailed` on dashboard; `/vms` lists 10 VMs (grafana…ntp) with `Name|IP|State|vCPU|RAM|Health|Ports`, network table shows `br0` + VM taps. Dark dense monospace styling.
- No WebSocket/auth/SQLite yet — observability first. M1-full will add agent WS protocol + full multi-host support.

### Roles
None (server profile, framework data in `data/hosts/mireo/` — `roles.nix` intentionally absent, manifest `roles: []`)

### Config files
- `data/hosts/mireo/settings.nix` — hostname, network, NAT, dnsmasq, Pixiecore/netboot.xyz, NFS, Avahi, Netdata, **nixfleet M1** (`lucy.nixfleet.*`, firewall 8443)
- `hosts/mireo/optional-data.nix` — bounded mount waits, mount-bound data services and guarded tmpfiles initialization
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
| fxsync | 10.8.0.31 | 1024 MB | 1 | 2 GB sync data |
| dash | 10.8.0.32 | 1024 MB | 1 | 512 MB state |

### Monero port forwarding
Port 9001/tcp (Tor ORPort) forwarded from WAN to monerod VM.

### Deploy
```bash
nix run .#deploy-mireo   # SSH to mireo via deploy-rs (10.8.0.1 on LAN, 192.168.178.25 from FritzBox LAN)
deploy .#mireo           # same, via deploy-rs directly
```
