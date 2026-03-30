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
github:nix-community/home-manager
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
- Used for color scheme and font configuration

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

## Not Yet Integrated

### flake-parts
- Not added yet - original hand-rolled flake.nix works fine
- Would provide: modular flake output organization

### microvm.nix
- Not added yet - requires nixos-hardware first
- Would provide: declarative microVM management

### sops-nix
- Not added yet - planned for secrets management
- Would provide: age-based secrets encryption

### nixos-hardware
- Not added yet - planned for ThinkPad P50 hardware configuration
- Would provide: NVIDIA PRIME config, proper hardware modules
