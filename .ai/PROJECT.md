# Project Overview

## Structure
```
dotfiles/
├── flake.nix              # Main flake with deploy-rs
├── flake.lock
├── .sops.yaml            # SOPS config
├── setup-sops.sh          # SOPS setup script
├── .ai/                   # AI session summaries
│   └── session-*.md
├── modules/
│   ├── nixos/            # NixOS system modules
│   │   ├── base.nix      # Base config (SSH, sudo, libvirt, sops)
│   │   ├── network.nix   # Static IP module
│   │   ├── glasfaser.nix # Telekom PPPoE (VLAN 7)
│   │   ├── sops.nix      # Secrets management
│   │   ├── asterisk.nix  # Asterisk SIP PBX
│   │   ├── nvidia.nix    # NVIDIA GPU config
│   │   ├── gnome.nix     # GNOME desktop
│   │   ├── gnome-extensions.nix
│   │   ├── latex.nix     # LaTeX environment
│   │   ├── openclaude.nix # BROKEN - npm issues
│   │   └── packages.nix  # User packages
│   └── desktop/
│       └── audio-zeroconf.nix  # HQ zeroconf audio
├── hosts/
│   ├── p50/              # ThinkPad P50 (Intel)
│   ├── desktop/           # GTX 1070 desktop
│   └── omen/              # RTX 2070 desktop
└── home/lucy/            # Home-manager config
```

## Hosts
| Host    | GPU        | Network          | Features                    |
|---------|------------|------------------|-----------------------------|
| p50     | Intel      | enp0s31f6        | asterisk, latex, wayland   |
| desktop | GTX 1070   | enp8s0           | nvidia, audio-zeroconf      |
| omen    | RTX 2070   | enp60s0          | nvidia, suspend/resume fixes |

## Module Options
- `lucy.base.*` - SSH keys, sudo config
- `lucy.gnome.*` - GNOME settings, wayland toggle
- `lucy.nvidia.*` - GPU config
- `lucy.openclaude.*` - BROKEN
- `lucy.latex.*` - LaTeX packages
- `hq.audio.*` - Zeroconf audio streaming
- `services.asteriskLocal.*` - Asterisk PBX

## Secrets
- SOPS with age encryption
- Key: `~/.sops/keys.txt`
- Public: `age167kzcnwsvnttkgahnvlcrhh9wdx8ks8rwc89vr3n6qtcddr3jd4s580m67`
