# NixOS Dotfiles

NixOS and Home Manager config for `omen`, with an increasing focus on a self-hosted Nix framework.

## Quick Start

```bash
nix run .#rebuild
nix run .#check
nix run .#update
```

Direct rebuild still works:

```bash
nixos-rebuild switch --flake .#omen
```

## Current Structure

```text
.
├── flake.nix
├── lib/                 # Framework helpers, renderers, symbols
├── data/                # Package, bundle, host, and preset registries
├── modules/
│   ├── nixos/           # Reusable NixOS modules
│   └── home/            # Reusable Home Manager modules
├── hosts/omen/          # Host-specific composition
├── home/lucy/           # User-specific composition
└── docs/                # Framework notes
```

## Framework Direction

The repo is being reshaped around four layers:

- `lib/`: reusable functions and renderers
- `data/`: declarative registries for packages, bundles, hosts, and presets
- `modules/`: NixOS and Home Manager modules that consume the registries
- `hosts/` and `home/`: concrete host and user composition

See `docs/framework.md` for the framework reference.
See `docs/data-model.md` for the data schema reference.
See `docs/gaming-omen.md` for the current `omen` gaming setup.

## Host

| Host | Type | GPU | Notes |
|------|------|-----|-------|
| omen | Laptop | NVIDIA RTX 2070 | Niri, gaming presets, suspend fix |

## Secrets Management

```bash
./setup-sops.sh
SOPS_AGE_KEY_FILE=~/.sops/keys.txt nvim hosts/omen/secrets.yaml
```

## Common Commands

```bash
nix flake check
nix flake update
nix fmt
```

## Current Focus

- move more config into registries under `data/`
- reduce raw config text in modules
- expand `omen` gaming setup through reusable presets
- keep `nix flake check` green after every refactor
