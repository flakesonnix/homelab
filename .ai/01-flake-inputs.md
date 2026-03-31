# Flake Inputs - Full Documentation

## Input: nixpkgs

### URL
```
github:NixOS/nixpkgs/nixos-unstable
```

### Purpose
- Primary nixpkgs instance for all packages and NixOS modules
- Used for: nixosConfigurations, homeConfigurations, devShells, formatter

### Wiring
- Referenced directly in flake.nix outputs
- home-manager follows this input (inputs.nixpkgs.follows = "nixpkgs")

---

## Input: home-manager

### URL
```
github:nix-community/home-manager/master
```

### Purpose
- Provides home-manager NixOS module for user configuration management
- Provides home-manager lib for standalone configurations
- Follows nixpkgs input to avoid duplicate package instances

### Wiring
- `home-manager.nixosModules.home-manager` imported in nixosConfigurations.p50
- `home-manager.lib.homeManagerConfiguration` used for homeConfigurations."lucy@p50"
- `inputs.nixpkgs.follows = "nixpkgs"` to deduplicate

---

## Input: stylix

### URL
```
github:nix-community/stylix
```

### Purpose
- Provides theming system for NixOS/home-manager
- Used for: color scheme and font configuration

### Wiring
- `stylix.homeModules.stylix` imported in home configurations
- `inputs.nixpkgs.follows = "nixpkgs"` to deduplicate

---

## Input: wrappers

### URL
```
github:lassulus/wrappers
```

### Purpose
- Provides wrapper modules for declarative package configuration
- Used for: niri configuration (converts Nix attrs to KDL), hyfetch flags

### Wiring
- `wrappers.wrapperModules.niri.apply` used in hosts/p50/default.nix
- `wrappers.lib.wrapPackage` used for hyfetch with custom flags
- `inputs.nixpkgs.follows = "nixpkgs"` to deduplicate

---

## Input: nix-flatpak

### URL
```
github:gmodena/nix-flatpak
```

### Purpose
- Declarative flatpak management for NixOS/home-manager
- Used for: TeamSpeak via flatpak (avoids qtwebengine dependency)

### Wiring
- `nix-flatpak.homeManagerModules.nix-flatpak` imported in home-manager
- `services.flatpak.packages` for flatpak installation
- `inputs.nixpkgs.follows = "nixpkgs"` to deduplicate

---

## Input: nixos-hardware

### URL
```
github:NixOS/nixos-hardware
```

### Purpose
- Hardware-specific NixOS modules for various devices
- Used for: ThinkPad P50 hardware configuration

### Wiring
- `nixos-hardware.nixosModules.lenovo-thinkpad-p50` imported in nixosConfigurations
- `inputs.nixpkgs.follows = "nixpkgs"` to deduplicate

---

## Input: sops-nix

### URL
```
github:Mic92/sops-nix
```

### Purpose
- Declarative secrets management with age encryption
- Used for: secrets.yaml-based secret storage

### Wiring
- `sops-nix.nixosModules.sops` imported in nixosConfigurations
- `services.sops` configuration in hosts/p50/default.nix
- `inputs.nixpkgs.follows = "nixpkgs"` to deduplicate

---

## Input: flake-parts

### URL
```
github:hercules-ci/flake-parts
```

### Purpose
- Modular flake output organization
- Used for: cleaner flake structure with perSystem configuration

### Wiring
- `flake-parts.lib.mkFlake { inherit inputs; }` wraps flake outputs
- `systems` and `perSystem` for multi-system support
- `inputs.nixpkgs.follows = "nixpkgs"` to deduplicate

---

## Input: microvm

### URL
```
github:microvm-nix/microvm.nix
```

### Purpose
- Provides lightweight NixOS virtual machine management
- Used for: declarative microVM configuration

### Wiring
- `microvm.nixosModules.microvm` imported in hosts/vm/default.nix
- `inputs.nixpkgs.follows = "nixpkgs"` to deduplicate
- `nixosConfigurations.microvm` added to flake outputs

### Configuration
- Hypervisor: qemu
- Resources: 2 vCPUs, 1024MB RAM
- Networking: TAP interface (microvm-br0)
- 9p share for nix-store

---

## Future Integrations

### microvm.nix
- Can be added when needed
- Currently disabled due to flake check path issues
- Would provide: declarative microVM management
