---
aliases: [Gaming, Gaming stack]
tags: [module, nixos, guide]
type: module
namespace: lucy.gaming.*
---

# Gaming stack (p53)

[[20-Modules/Modules-MOC|← Modules]] · [[10-Hosts/p53|p53]] · Source `docs/gaming-p53.md`, `modules/nixos/gaming/` (6), `data/presets/gaming-*.nix`.

The `gaming` role activates 3 presets:

| Preset | Enables |
|--------|-------|
| `gaming-base` | `lucy.gaming.enable=true` (loads `gaming.nix`) |
| `gaming-performance` | `performance` CPU governor, power-profiles-daemon off, capSysNice, low-latency sysctl |
| `gaming-steam` | Steam, GameMode, Gamescope, MangoHud |

## Submodules

- `common`: 32-bit graphics, `extraGroups=[gamemode]`, kernel params
- `steam`: `programs.steam/gamemode/gamescope/mangohud`
- `audio`: PipeWire latency tweaks (smaller buffers)
- `performance`: `cpuFreqGovernor`, disables power-profiles-daemon
- `sysctl`: `net.core.netdev_max_backlog` and friends
- `systemd`: CPU isolation/scheduling tweaks

## Usage

```bash
MANGOHUD=1 %command%   # Steam launch option
gamescope -W 1920 -H 1080 -f -- %command%
gamemoderun ./game
```

Without the `gaming` role everything stays inactive (purely additive). Governor is always `performance` while the preset is active.
