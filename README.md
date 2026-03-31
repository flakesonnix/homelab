# NixOS Dotfiles for Lucy's ThinkPad P50

This is a declarative NixOS configuration repository following nixpkgs maintainer conventions. It uses home-manager for user configuration, flake-based deployment, and modular architecture.

## Architecture

```
dotfiles/
├── flake.nix              # Entry point, defines all inputs/outputs
├── flake.lock             # Pinned versions for all inputs
├── lib/                   # Helper functions (mkUser)
├── hosts/                 # Host-specific NixOS configurations
│   └── p50/              # ThinkPad P50 configuration
├── home/                  # home-manager user configurations
│   └── lucy/             # User lucy's home config
├── modules/               # Reusable NixOS/home-manager modules
│   ├── nixos/           # System-level modules
│   └── home/            # User-level modules
├── profiles/             # Composable system profiles
│   ├── base.nix         # Base system profile
│   └── desktop.nix      # Desktop profile with GNOME
└── nix-settings.nix     # Nix settings (flakes, auto-optimise)
```

## Quickstart

### Install on Fresh NixOS

```bash
# Clone the repo
git clone https://github.com/yourusername/dotfiles.git /etc/nixos

# Build the system
sudo nixos-rebuild switch --flake .#p50

# Or build home-manager config
home-manager switch --flake .#lucy@p50
```

### Development Shell

```bash
# Enter dev shell with nix tools
nix develop

# Format all Nix files
nix fmt
```

## Adding a New Host

Create `hosts/<hostname>/default.nix`:

```nix
{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "newhost";

  users.users.lucy = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
  };

  # ... your config
}
```

Add to `flake.nix`:

```nix
nixosConfigurations.newhost = nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [ ./hosts/newhost ];
};
```

## Adding a New User

Use `mkUser` from `lib/default.nix`:

```nix
mkUser {
  username = "newuser";
  description = "New User";
  modules = [ ./home/newuser ];
}
```

## Adding a New Module

### NixOS Module (`modules/nixos/`)

```nix
{ lib, config, ... }:

{
  options.myModule.enable = lib.mkEnableOption "my awesome module";

  config = lib.mkIf config.myModule.enable {
    # Your config here
    environment.systemPackages = [ pkgs.hello ];
  };
}
```

### Home Manager Module (`modules/home/`)

```nix
{ lib, config, ... }:

{
  options.lucy.myModule = {
    enable = lib.mkEnableOption "my user module";
  };

  config = lib.mkIf config.lucy.myModule.enable {
    home.packages = [ pkgs.hello ];
  };
}
```

## Modules Reference

| Module | Location | Purpose |
|--------|----------|---------|
| niri | `modules/nixos/niri.nix` | Wayland compositor |
| nix-settings | `nix-settings.nix` | Nix configuration |
| base profile | `profiles/base.nix` | Base system config |
| desktop profile | `profiles/desktop.nix` | GNOME + pipewire |

## Flake Inputs

| Input | URL | Purpose |
|-------|-----|---------|
| nixpkgs | `github:NixOS/nixpkgs/nixos-unstable` | Packages and modules |
| home-manager | `github:nix-community/home-manager` | User environment |

## Common Commands

```bash
# Update all flake inputs
nix flake update

# Check configuration
nix flake check

# Build system
nix build .#nixosConfigurations.p50.config.system.build.toplevel

# Format code
nix fmt
```

## Hardware Notes (p50)

- ThinkPad P50 with Intel HD Graphics 530 + NVIDIA Quadro M1000M
- Network: Ethernet (enp0s31f6) + WiFi (wlp4s0)
- Storage: LUKS encrypted root + swap
