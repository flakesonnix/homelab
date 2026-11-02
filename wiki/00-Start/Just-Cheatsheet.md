---
aliases: [Cheatsheet, Just, Commands]
tags: [start, guide, reference]
type: guide
---

# Just cheatsheet

[[Home|← Home]] · Source: `justfile`, `flake.nix` apps.

| Command | What happens |
|--------|--------------|
| `just` | List recipes |
| `just menu` / `nix run .#menu` | fzf launcher |
| `just rebuild` | `nix run .#rebuild` → `nh os switch` (local p53) |
| `just deploy` / `just deploy-p53` | deploy-rs → localhost |
| `just deploy-mireo` | deploy-rs → 10.8.0.1 |
| `just deploy-all` | p53 and mireo |
| `just check-light` | eval surface |
| `just check` | `nix run .#check` (full) |
| `just check-full` | builds only |
| `just update` | `nix flake update` |
| `just fmt` / `just fmt-check` | Format/check tracked Nix source with RFC 166 nixfmt; skip generated hardware configs |
| `just lint` | `statix check` |
| `just sops [host]` | Generate `.sops/keys.txt`; install the private key on the target separately |
| `just topology` | `nix build .#topology` → `result/{main,network}.svg`; CI updates `docs/topology/` |
| `just pxe-boot` | Build optional Xfce installer; normal PXE uses Pixiecore/netboot.xyz |
| `just nixfleet` | `nix run .#nixfleet` CLI |
| `just docs-generate/check/build/serve` | NixFleet docs framework |
| `just new-host <name>` | `scripts/new-host.sh host <name>` |
| `just new-vm <name>` | `scripts/new-host.sh vm <name>` (+ register IP in `vm-ips.nix`) |

## Session keys (p53, [[20-Modules/Home-Modules|Home modules]])

SwayFX (also the retained Niri layout): `Alt+Enter` alacritty · `Alt+D` fuzzel · `Alt+Shift+A` pwvucontrol · `Alt+Ctrl+Esc` swaylock · `Alt+Shift+S` screenshot.

dwl-scroll: `Super+Enter` alacritty · `Super+D` built-in launcher · `Super+W` close · `Super+F` maximize column · `Super+Shift+F` fullscreen · `Super+Ctrl+Esc` manual lock. No idle locker is configured in dwl-scroll. Full keymap: `docs/dwl-scroll.md`.

## NixFleet endpoints (mireo :8443)

`GET /api/v1/hosts`, `/:host/{health,resources,network,vms,systemd/failed}` — details [[50-NixFleet/Manifest-API|Manifest & API]].
