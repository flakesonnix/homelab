# Hosts

## Network Layout

```
Internet
    │
    │ 192.168.178.25
  mireo (router)
    │
    │ 10.8.0.1 (br0)
    ├── 10.8.0.2  grafana microvm  (Prometheus + Grafana)
    ├── 10.8.0.4  monerod microvm  (Monero node + Tor relay)
    ├── 10.8.0.122  p50
    ├── 10.8.0.163  x61
    └── 10.8.0.176  omen
```

mireo also bridges microvms onto br0 via tap interfaces. NAT masquerade on `enp4s0` (WAN).

All machines mount `10.8.0.1:/data` via NFS at `/mnt/mireo/data` (automount, 600s idle timeout).

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
- Audio streaming (RTP SAP receive via PipeWire)
- Tailscale, Bluetooth

### Roles
`desktop`, `dev`, `llm`, `gaming`

### Config files
- `data/hosts/omen/settings.nix` — hostname, hosts, Bluetooth, Niri users, boot params
- `data/hosts/omen/roles.nix` — role list
- `hosts/omen/host.nix` — framework applyHost call
- `hosts/omen/hardware-configuration.nix` — nixos-hardware-generated

### Special modules loaded
`asterisk`, `audio-stream`, `fonts`, `gaming`, `gnome`, `gnome-extensions`, `niri`, `nvidia`, `nvidia-resume`, `serial-getty`, `sops`, `waybar`, `lanzaboote`

### Rebuild
```bash
# Local (preferred)
nix run .#rebuild
# or
sudo nixos-rebuild switch --flake ~/Documents/dotfiles#omen

# Via deploy-rs
nix run .#deploy-omen
```

---

## p50

**Role:** Desktop workstation  
**Hardware:** ThinkPad P50, NVIDIA (forced to legacy_535 driver)  
**IP:** 10.8.0.122

### Features
- GNOME shell (niri disabled)
- Pipebert audio sink ("P50 Speakers") — PipeWire TCP + AirPlay
- NVIDIA legacy_535 package override (`lib.mkForce` in `hosts/p50/host.nix`)
- Power management disabled for NVIDIA on this machine

### Roles
`desktop`, `dev`

### Config files
- `data/hosts/p50/settings.nix` — hostname, pipebert config, GNOME enable, NVIDIA overrides
- `data/hosts/p50/roles.nix` — role list
- `hosts/p50/host.nix` — framework applyHost + legacy_535 override

### Deploy
```bash
nix run .#deploy-p50   # SSH to p50 (10.8.0.122)
```

---

## mireo

**Role:** Home server and LAN router  
**Hardware:** Mini-PC with 4-port NIC (enp4s0 WAN, enp9s0/enp3s0f0/enp3s0f1 bridged to br0)  
**IP:** 10.8.0.1 (LAN), 192.168.178.25 (WAN)

### Features
- NAT gateway for 10.8.0.0/24
- systemd-networkd (no NetworkManager)
- Four microVMs running on br0:
  - **grafana** (10.8.0.2): Prometheus scraping router + all hosts, Grafana with mireo-router dashboard
  - **monerod** (10.8.0.4): Pruned Monero node + Tor relay (nickname `mireoMoneroRelay`)
  - **network-services** (10.8.0.3): DHCP, DNS, PXE
  - **yammat** (10.8.0.5): Event management (YAMMAT)
- No desktop (`lucy.base.isServer = true`)
- node_exporter running on 10.8.0.1:9100 for self-monitoring

### Roles
None (server profile, framework data in `data/hosts/mireo/`)

### Config files
- `data/hosts/mireo/settings.nix` — hostname, network layout, NAT, firewall
- `hosts/mireo/host.nix` — framework applyHost
- `hosts/mireo/grafana-microvm.nix` — grafana + prometheus microvm
- `hosts/mireo/monerod-microvm.nix` — monerod + Tor microvm
- `hosts/mireo/network-services-microvm.nix` — microvm bridge wiring

### Microvm resource allocation
| VM | IP | Memory | vCPUs | Storage |
|----|-----|--------|-------|---------|
| grafana | 10.8.0.2 | 768 MB | 2 | 1 GB grafana + 1 GB prometheus |
| network-services | 10.8.0.3 | 512 MB | 1 | — |
| monerod | 10.8.0.4 | 2304 MB | 2 | 350 GB blockchain |
| yammat | 10.8.0.5 | 512 MB | 1 | 10 GB |

### Monero port forwarding
Port 9001/tcp (Tor ORPort) forwarded from WAN to monerod VM.

### Deploy
```bash
nix run .#deploy-mireo   # SSH to mireo (192.168.178.25)
```

---

## x61

**Role:** Kiosk display  
**Hardware:** ThinkPad X61  
**IP:** 10.8.0.163

### Features
- Auto-login as `lucy` into a custom LightDM kiosk session
- Kiosk session runs `firefox --kiosk` pointed at the Grafana dashboard (`http://10.8.0.2:3000/d/mireo-router/mireo-router?kiosk`)
- Screen blanking disabled (xset s off, -dpms, s noblank)
- Pipebert enabled (open firewall)
- NFS mount of mireo data share
- GRUB bootloader (`/dev/sda`)

### Config files
- `hosts/x61/host.nix` — full standalone config (no framework, no profile)
- `hosts/x61/hardware-configuration.nix`

### Deploy
```bash
nix run .#deploy-x61   # SSH to x61 (10.8.0.163)
```
