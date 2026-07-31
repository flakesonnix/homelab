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
    ├── 10.8.0.8  aptcache microvm    (apt-cacher-ng proxy)
    └── 10.8.0.176  omen
```

mireo bridges microvms onto br0 via tap interfaces. NAT masquerade on `enp4s0` (WAN). IPv6 prefix `2a02:3102:4cec:b500::/64` delegated from FritzBox to br0; dnsmasq issues RA (ra-stateless) to LAN clients.

---

## omen

**Role:** Primary desktop / gaming laptop  
**Hardware:** HP Omen laptop, NVIDIA RTX 2070  
**IP:** 10.8.0.176

### Features
- Niri Wayland compositor with eww desktop shell (topbar + sidebar)
- Stylix theming (cyberdeck/dark palette)
- Secure Boot via lanzaboote
- NVIDIA: lazy-load modprobe service, s2idle suspend, PRIME not enabled
- Gaming: Steam, GameMode, Gamescope (capSysNice), MangoHud, performance governor
- Asterisk SIP PBX
- Audio streaming → remote tunnel sink
- Tailscale, Bluetooth
- Waydroid (Android container, initialised with GAPPS image via oneshot service)

### Roles
`desktop`, `dev`, `gaming`

### Config files
- `data/hosts/omen/settings.nix` — hostname, hosts, Bluetooth, Niri users, boot params
- `data/hosts/omen/module-flags.nix` — NixOS feature toggles (nvidia, fonts, waydroid, etc.)
- `data/hosts/omen/roles.nix` — role list
- `hosts/omen/host.nix` — framework applyHost call
- `hosts/omen/hardware-configuration.nix` — nixos-hardware-generated

### Special modules loaded
`asterisk`, `audio-stream`, `deskflow`, `fonts`, `gaming`, `gnome`, `gnome-extensions`, `niri`, `nvidia`, `nvidia-resume`, `serial-getty`, `sops`, `waybar`, `waydroid`, `lanzaboote`

### Rebuild
```bash
# Local (preferred)
nix run .#rebuild
# or
sudo nixos-rebuild switch --flake ~/Documents/dotfiles#omen

# Via deploy-rs
nix run .#deploy-omen
```



## mireo

**Role:** Home server and LAN router  
**Hardware:** Mini-PC with 4-port NIC (enp4s0 WAN, enp9s0/enp3s0f0/enp3s0f1 bridged to br0)  
**IP:** 10.8.0.1 (LAN), 192.168.178.25 (WAN)

### Features
- NAT gateway for 10.8.0.0/24 + IPv6 (FritzBox DHCPv6-PD, prefix `2a02:3102:4cec:b500::/64`)
- systemd-networkd (no NetworkManager)
- dnsmasq on host: DHCP, DNS, IPv6 RA (ra-stateless) for LAN (br0)
- iVentoy PXE server via OCI container (Podman, `--network=host`, proxyDHCP mode, web UI :26000)
- NFS export of `/data` to `10.8.0.0/24`
- Avahi mDNS advertising NFS share (`_nfs._tcp`) for Nautilus autodiscovery
- Netdata monitoring (10.8.0.1:19999)
- Seven microVMs running on br0:
  - **grafana** (10.8.0.2): Prometheus scraping router + all hosts, Grafana with mireo-router dashboard
  - **network-services** (10.8.0.3): bridge tap stub (no services)
  - **monerod** (10.8.0.4): Pruned Monero node + Tor relay (nickname `mireoMoneroRelay`)
  - **yammat** (10.8.0.5): YAMMAT event management (C3D2 matemat, port 3000)
  - **cups** (10.8.0.6): CUPS print server (IPP, Avahi, Epson ET-2860 + Lexmark)
  - **sshkeys** (10.8.0.7): Nginx serving SSH public keys
  - **aptcache** (10.8.0.8): apt-cacher-ng caching proxy for LAN
- No desktop (`lucy.base.isServer = true`)
- node_exporter running on 10.8.0.1:9100 for self-monitoring
- CLI tools: tcpdump, mtr, nmap, iperf3, ethtool, socat, btop, htop, ncdu, jq, lsof, sysstat, smartmontools

### Roles
None (server profile, framework data in `data/hosts/mireo/`)

### Config files
- `data/hosts/mireo/settings.nix` — hostname, network, NAT, dnsmasq, NFS, Avahi, iVentoy, Netdata
- `hosts/mireo/host.nix` — framework applyHost
- `hosts/mireo/grafana-microvm.nix` — grafana + prometheus microvm
- `hosts/mireo/monerod-microvm.nix` — monerod + Tor microvm
- `hosts/mireo/network-services-microvm.nix` — network-services bridge tap stub
- `hosts/mireo/yammat-microvm.nix` — YAMMAT microvm
- `hosts/mireo/cups-microvm.nix` — CUPS print server microvm
- `hosts/mireo/sshkeys-microvm.nix` — SSH public key web server microvm
- `hosts/mireo/aptcache-microvm.nix` — apt-cacher-ng proxy microvm
- `hosts/mireo/microvm-base.nix` — shared microvm base config

### Microvm resource allocation
| VM | IP | Memory | vCPUs | Storage |
|----|-----|--------|-------|---------|
| grafana | 10.8.0.2 | 768 MB | 2 | 1 GB grafana + 1 GB prometheus |
| network-services | 10.8.0.3 | 384 MB | 1 | — |
| monerod | 10.8.0.4 | 2304 MB | 2 | 350 GB blockchain |
| yammat | 10.8.0.5 | 2304 MB | 2 | 8 GB postgres + 128 MB state |
| cups | 10.8.0.6 | 512 MB | 1 | 256 MB cups config |
| sshkeys | 10.8.0.7 | 256 MB | 1 | — |
| aptcache | 10.8.0.8 | 512 MB | 1 | 8 GB cache |

### Monero port forwarding
Port 9001/tcp (Tor ORPort) forwarded from WAN to monerod VM.

### Deploy
```bash
nix run .#deploy-mireo   # SSH to mireo (192.168.178.25 or 10.8.0.1)
```

