---
aliases: [Cheatsheet, Just, Commands]
tags: [start, guide, reference]
type: guide
---

# Just cheatsheet

[[Home|← Home]] · Source: `justfile`, `flake.nix` apps.

| Command | What happens |
|--------|--------------|
| `just` / `nix run .#menu` | fzf launcher (all entries) |
| `just rebuild` | `nix run .#rebuild` → `nh os switch` (local x270) |
| `just deploy` / `just deploy-x270` | deploy-rs → localhost |
| `just deploy-mireo` | deploy-rs → 10.8.0.1 |
| `just deploy-nyagate` | deploy-rs → db210.org |
| `just deploy-all` | all three |
| `just check-light` | eval surface |
| `just check` | `nix run .#check` (full) |
| `just check-full` | builds only |
| `just update` | `nix flake update` |
| `just fmt` | `nix fmt` (alejandra) |
| `just lint` | `statix check` |
| `just sops [host]` | `nix run .#setup-sops x270` → `/etc/sops/age/keys.txt` |
| `just topology` | `nix build .#topology` → `docs/topology/{main,network}.svg` |
| `just nixfleet` | `nix run .#nixfleet` CLI |
| `just docs-generate/check/build/serve` | NixFleet docs framework |
| `just new-host` | `scripts/new-host.sh host <name>` |

## Niri keys (x270, [[20-Modules/Home-Modules|Home modules]])

`Alt+Enter` alacritty · `Alt+D` fuzzel · `Alt+Shift+A` pwvucontrol · `Alt+Ctrl+Esc` swaylock · `Alt+Shift+S` screenshot.

## NixFleet endpoints (mireo :8443)

`GET /api/v1/hosts`, `/:host/{health,resources,network,vms,systemd/failed}` — details [[50-NixFleet/Manifest-API|Manifest & API]].
