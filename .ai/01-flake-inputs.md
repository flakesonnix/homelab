# Flake Inputs - Full Documentation

## Input: nixpkgs

### URL
```
github:NixOS/nixpkgs/24.11
```

### Version (from flake.lock)
```
rev: 8b27c1239e5c421a2bbc2c65d52e4a6fbf2ff296
lastModified: 1731603435 (2024-11-14)
narHash: sha256-CqCX4JG7UiHvkrBTpYC3wcEurvbtTADLbo3Ns2CEoL8=
```

### Purpose
- Primary nixpkgs instance for all packages and NixOS modules
- Pinned to NixOS 24.11 stable release (channel: nixos-24.11)
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

### Version (from flake.lock)
```
rev: 769e07ef8f4cf7b1ec3b96ef015abec9bc6b1e2a
lastModified: 1774738535 (2026-03-28)
narHash: sha256-2jfBEZUC67IlnxO5KItFCAd7Oc+1TvyV/jQlR+2ykGQ=
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

## Previously Integrated (REMOVED/FAILED)

### niri-flake
- URL: github:sodiboo/niri-flake
- Status: REMOVED due to module compatibility issues
- Was intended for: home-manager module to generate niri KDL config
- Reason for removal: niri-flake.nixosModules conflicted with nixpkgs console.nix

### nixos-hardware
- URL: github:NixOS/nixos-hardware
- Status: REMOVED due to nixpkgs bug (mkRenamedOptionModule)
- Was intended for: ThinkPad P50 hardware configuration
- Reason for removal: nixos-hardware imports triggered lib.mkRenamedOptionModule error with broken nixpkgs

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

### awesome-nix tools
- Various tools from awesome-nix not yet evaluated for integration
- See: 05-design-decisions.md for evaluation criteria
