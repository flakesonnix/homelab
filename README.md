# NixOS Dotfiles

NixOS configuration for `omen`.

## Hosts

| Host | Type | GPU | Notes |
|------|------|-----|-------|
| omen | Desktop PC | NVIDIA RTX 2070 | Niri, suspend fix |

## Quick Start

```bash
# Direct rebuild
nixos-rebuild switch --flake .#omen
```

## Secrets Management (sops-nix)

```bash
# Generate age key
./setup-sops.sh

# Edit secrets (use your editor)
SOPS_AGE_KEY_FILE=~/.sops/keys.txt nvim hosts/omen/secrets.yaml
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
├── modules/nixos/        # Reusable modules
│   ├── base.nix          # Base config (SSH, sudo, libvirt)
│   ├── network.nix       # Static IP configuration
│   ├── nvidia.nix        # NVIDIA GPU + suspend fixes
│   ├── gnome.nix         # GNOME desktop
│   ├── gnome-extensions.nix
│   ├── latex.nix         # LaTeX writing environment
│   ├── asterisk.nix      # Asterisk SIP PBX
│   └── packages.nix      # Base packages
├── hosts/
│   └── omen/
└── home/lucy/            # Home-manager user config
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
