# AGENTS.md

NixOS flake-based dotfiles. deploy-rs for remote deploy.

## Deploy

```bash
deploy .#omen      # → 192.168.178.4
deploy .#homelab   # → 192.168.178.177
```

Local rebuild: `nixos-rebuild switch --flake .#omen`

## Validate

```bash
nix flake check      # Validate config
nix flake update    # Update inputs
nix fmt            # Format code (nixpkgs-fmt)
```

## Secrets (sops-nix)

```bash
./setup-sops.sh                    # Generate age key
SOPS_AGE_KEY_FILE=~/.sops/keys.txt nvim hosts/p50/secrets.yaml
```

## Hosts

| Host | Profile | IP | GPU |
|------|---------|-----|-----|
| omen | desktop | 192.168.178.4 | RTX 2070 |
| homelab | base | 192.168.178.177 | - |

## Architecture

- `flake.nix`: Main entry, defines nixosConfigurations + homeConfigurations
- `hosts/<host>/`: Host-specific NixOS config
- `home/lucy/`: Home-manager user config
- `modules/nixos/`: Reusable NixOS modules
- `modules/home/`: Home-manager modules (option prefix: `lucy.<module>.enable`)
- `profiles/`: Composable module collections

## New Module

NixOS module → `modules/nixos/<name>.nix`:

```nix
{ lib, config, pkgs, ... }:

{
  options.myModule.enable = lib.mkEnableOption "my module";
  config = lib.mkIf config.myModule.enable {
    environment.systemPackages = [ pkgs.myPackage ];
  };
}
```

Home module → `modules/home/<name>.nix`:

```nix
{ lib, config, ... }:

{
  options.lucy.myModule.enable = lib.mkEnableOption "my user module";
  config = lib.mkIf config.lucy.myModule.enable {
    home.packages = [ pkgs.myPackage ];
  };
}
```

## Gotchas

- `specialArgs` passes `{ wrappers, inputs }` to NixOS configs
- Home-manager imports in flake.nix `home-manager.users.lucy.imports`
- Option naming: `users.users.lucy.isNormalUser = true`
- nixpkgs: `nixos-unstable` branch