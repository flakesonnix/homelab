# NixOS Dotfiles

NixOS flake managing four machines for user `lucy`. Built on the [rivotril](https://github.com/flakesonnix/rivotril) framework for data-driven host and home composition.

## Hosts

| Host | Role | Hardware | Notes |
|------|------|----------|-------|
| `omen` | Desktop / gaming laptop | HP Omen, NVIDIA RTX 2070 | Primary machine. Niri compositor, eww bar, Secure Boot |
| `p50` | Desktop workstation | ThinkPad P50, NVIDIA (legacy 535) | GNOME fallback, Pipebert audio sink |
| `mireo` | Home server / router | Mini-PC, 4-port NIC | NAT gateway, microvms: grafana, monerod |
| `x61` | Kiosk display | ThinkPad X61 | Auto-boots Firefox → Grafana dashboard |

Network: `10.8.0.0/24` bridged on mireo. See [docs/hosts.md](docs/hosts.md) for full details.

## Layout

```
.
├── flake.nix               # Flake inputs, host configs, deploy nodes, apps
├── nix-settings.nix        # Global nix daemon settings (substituters, caches)
├── profiles/
│   ├── base.nix            # Shared NixOS base (imported by all hosts)
│   └── desktop.nix         # Desktop additions on top of base
├── data/
│   ├── roles/              # Role definitions (desktop, dev, gaming, llm, core)
│   ├── bundles/            # Home Manager bundle definitions (core, desktop, dev)
│   ├── presets/            # Host preset definitions (gaming-base, -performance, -steam)
│   ├── packages/
│   │   ├── system.nix      # Tagged system package registry
│   │   └── home.nix        # Tagged home package registry
│   ├── hosts/<host>/       # Per-host settings, roles, module flags
│   └── home/lucy/          # Per-user bundles, roles, settings
├── modules/
│   ├── nixos/              # Reusable NixOS modules
│   └── home/               # Reusable Home Manager modules
├── hosts/
│   ├── omen/               # Hardware config + framework host.nix
│   ├── p50/
│   ├── mireo/              # + microvm definitions (grafana, monerod)
│   └── x61/                # Standalone host (no framework)
├── home/lucy/              # User composition entry point
├── keys/                   # SSH public keys
├── webui/                  # Static Nix-generated docs site
├── lib/                    # Shared Nix functions
└── .sops.yaml              # sops encryption rules
```

## Common Commands

```bash
# Rebuild (local, via nh)
nix run .#rebuild

# Deploy to a remote host
nix run .#deploy-p50
nix run .#deploy-mireo
nix run .#deploy-x61

# CI checks
nix run .#check-light   # Fast: eval surfaces only
nix run .#check-full    # Full: build all CI checks

# Update inputs
nix run .#update

# Direct nixos-rebuild
nixos-rebuild switch --flake .#omen
```

Shell aliases available on omen: `rebuild`, `nix-rebuild`, `nix-clean`, `nix-update`.

## Data Model

Configuration is declared in `data/` and applied by the framework. See [docs/data-model.md](docs/data-model.md).

**Roles** (`data/roles/`) declare what a host or home should activate. Each role lists required/conflicting roles, target types, and maps to module flags, package tags, presets, or bundles.

**Bundles** (`data/bundles/`) declare Home Manager program toggles and settings for a slice of the home config.

**Presets** (`data/presets/`) declare sets of module flag values applied at the host level.

**Package registries** (`data/packages/`) are attr sets of tagged packages. Roles reference tags; the framework resolves which packages end up in the system.

## Modules

All custom NixOS and Home Manager modules live in `modules/`. See [docs/modules.md](docs/modules.md) for options reference.

Key modules:
- `nixos/base.nix` — `lucy.base.*`: SSH, timezone, locale, sudo, firewall, libvirtd
- `nixos/nvidia.nix` — `lucy.nvidia.*`: NVIDIA GPU with lazy-load service
- `nixos/pipebert.nix` — `lucy.pipebert.*`: Network audio sink (PipeWire TCP, AirPlay, Mopidy)
- `nixos/asterisk.nix` — `services.asteriskLocal.*`: Local SIP PBX
- `nixos/niri.nix` — `niri.users`: Niri + greetd/tuigreet host integration
- `nixos/gaming.nix` — aggregate: Steam, GameMode, Gamescope, performance tuning
- `home/niri.nix` — `programs.niri.enable`: Full KDL config, lock screen, wlogout
- `home/waybar.nix` — `programs.waybar.enable`: Styled bar with mpris, battery, CPU

## Secrets

Uses sops-nix with age keys. See [docs/secrets.md](docs/secrets.md).

Quick setup:
```bash
nix run .#setup-sops omen
SOPS_AGE_KEY_FILE=.sops/keys.txt sops hosts/omen/secrets.yaml
```

## CI

GitHub Actions (`.github/workflows/ci.yml`) runs three jobs on every push/PR:

| Job | What it checks |
|-----|---------------|
| `check-light` | Evaluates webui, formatter, devShell, and app derivation paths |
| `check-full` | Builds `full-ci-checks` (framework checks + deploy-rs schema checks) |
| `eval` | Evaluates `nixosConfigurations.omen.config.system.build.toplevel` |

## WebUI

Static HTML documentation site generated from Nix:

```bash
nix build .#webui
./result/bin/nixfiles-webui   # Serves on http://127.0.0.1:8080
```

Pages: dashboard, roles (host + home), presets, bundles.

## Dev Shell

```bash
nix develop
# provides: alejandra, python3, statix, nix-tree
```

Formatter: `nix fmt` (alejandra). Linter: `statix check`.

## Documentation

- [docs/hosts.md](docs/hosts.md) — Per-host hardware, roles, and network details
- [docs/data-model.md](docs/data-model.md) — Role, bundle, preset, and package registry shapes
- [docs/modules.md](docs/modules.md) — All nixos/ and home/ module options
- [docs/secrets.md](docs/secrets.md) — sops-nix key setup and rotation
- [docs/gaming-omen.md](docs/gaming-omen.md) — Gaming stack details for omen
