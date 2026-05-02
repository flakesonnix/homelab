# NixOS Dotfiles

NixOS and Home Manager config for `omen`, built around a small self-hosted Nix framework.

## Overview

The repository is split into four main layers:

- `lib/`
  Reusable helpers, validation, renderers, and framework entrypoints.
- `data/`
  Declarative roles, presets, bundles, package registries, and host/home selections.
- `modules/`
  Reusable NixOS and Home Manager modules.
- `hosts/` and `home/`
  Concrete host and user composition.

## Layout

```text
.
├── flake.nix
├── lib/                 # Framework helpers, validation, renderers
├── data/                # Roles, presets, bundles, package registries, host/home data
├── modules/
│   ├── nixos/           # Reusable NixOS modules
│   └── home/            # Reusable Home Manager modules
├── hosts/omen/          # Host wrapper and hardware imports
├── home/lucy/           # User-specific composition
└── docs/                # Framework and host reference docs
```

## Common Commands

Quick entrypoints:

```bash
nix run .#rebuild
nix run .#check
nix run .#update
```

Direct commands:

```bash
nixos-rebuild switch --flake .#omen
nix flake check
nix flake update
nix fmt
```

## Host

| Host | Type | GPU | Notes |
|------|------|-----|-------|
| omen | Laptop | NVIDIA RTX 2070 | Niri, gaming presets, Stylix-driven theme |

Host-specific declarative data lives under `data/hosts/omen/`.
The NixOS wrapper that applies it lives in `hosts/omen/host.nix`.

## Secrets

Initial setup:

```bash
./setup-sops.sh omen
SOPS_AGE_KEY_FILE=.sops/keys.txt sops hosts/omen/secrets.yaml
```

See `docs/secrets.md` for the full setup and rotation workflow.

## Documentation

- `docs/framework.md`
  Framework architecture, data flow, exported library entrypoints, and validation model.
- `docs/data-model.md`
  Role, preset, bundle, package registry, host, and home data shapes.
- `docs/gaming-omen.md`
  Gaming-specific notes for `omen`.
- `docs/secrets.md`
  `sops-nix` setup and Asterisk secret handling.

## Current Direction

- move more user configuration into structured bundle data
- keep validation wired into real host and home apply paths
- reduce handwritten string config where render helpers are a better fit
- keep `nix flake check` green after every refactor
