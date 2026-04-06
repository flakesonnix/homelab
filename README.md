# NixOS Dotfiles

Multi-host NixOS configuration with deploy-rs.

## Hosts

| Host | Type | GPU | Notes |
|------|------|-----|-------|
| p50 | ThinkPad Laptop | Intel HD 530 | Wayland |
| desktop | Desktop PC | NVIDIA GTX 1070 | X11 |
| omen | Desktop PC | NVIDIA RTX 2070 | X11, suspend fix |

## Quick Start

```bash
# Deploy to a host
deploy .#p50
deploy .#desktop  
deploy .#omen

# Direct rebuild
nixos-rebuild switch --flake .#p50
```

## Secrets Management (sops-nix)

```bash
# Generate age key
./setup-sops.sh

# Edit secrets (use your editor)
SOPS_AGE_KEY_FILE=~/.sops/keys.txt nvim hosts/p50/secrets.yaml

# Or use sops-edit
sops-edit hosts/p50/secrets.yaml
```

### secrets.yaml structure:

```yaml
keys:
  - &default_age <your-public-key>

secrets:
  pppoe-password: ENC[AES256_GCM,...]
  luks-key: ENC[AES256_GCM,...]
```

## Project Structure

```
.
├── flake.nix              # Main flake
├── modules/nixos/          # Reusable modules
│   ├── base.nix          # Base config (SSH, sudo, libvirt)
│   ├── network.nix       # Static IP configuration
│   ├── glasfaser.nix     # Telekom Glasfaser PPPoE
│   ├── nvidia.nix        # NVIDIA GPU + suspend fixes
│   ├── gnome.nix         # GNOME desktop
│   ├── gnome-extensions.nix
│   ├── latex.nix         # LaTeX writing environment
│   ├── asterisk.nix      # Asterisk SIP PBX
│   ├── openclaude.nix    # OpenClaude CLI
│   ├── packages.nix      # Base packages
│   └── sops.nix          # Secrets management
├── hosts/                 # Host-specific configs
│   └── p50/
│       └── secrets.yaml   # Encrypted secrets
└── home/lucy/           # Home-manager user config
```

## Modules Overview

| Module | Responsibility |
|--------|----------------|
| `base.nix` | SSH, sudo, libvirt, firewall, initrd SSH |
| `network.nix` | Static IP via NetworkManager |
| `glasfaser.nix` | Telekom VLAN 7 + PPPoE |
| `nvidia.nix` | GPU settings, suspend/resume |
| `gnome.nix` | Desktop environment |
| `asterisk.nix` | SIP PBX with PJSIP |
| `latex.nix` | TeX Live + texlab |

## Telekom Glasfaser Setup

```nix
networking.glasfaser = {
  enable = true;
  interface = "enp0s31f6";
  vlanId = 7;
  username = "user@t-online.de";
  passwordFile = /run/secrets/pppoe-password;
};
```

## Asterisk SIP PBX

```nix
services.asteriskLocal = {
  enable = true;
  openFirewall = true;
  phones = {
    desk1 = { extension = "1001"; password = "secret"; };
  };
};
```

After rebuild: `sudo asterisk -rx 'core reload'`

## Common Commands

```bash
nix flake check     # Validate config
nix flake update    # Update inputs
nix fmt            # Format code
```
