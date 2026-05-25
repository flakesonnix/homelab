# Gaming — omen

## Stack overview

Gaming on omen is driven by three presets (activated via the `gaming` role):

| Preset | What it enables |
|--------|----------------|
| `gaming-base` | `lucy.gaming.enable = true` (loads `modules/nixos/gaming.nix`) |
| `gaming-performance` | Performance CPU governor, disable power profiles daemon, Gamescope capSysNice, low-latency sysctl |
| `gaming-steam` | Steam, GameMode, Gamescope, MangoHud |

## Module breakdown

`modules/nixos/gaming.nix` is an aggregate that imports six submodules:

- **common.nix** — baseline: 32-bit graphics, `users.users.lucy.extraGroups = ["gamemode"]`, kernel parameters for gaming
- **steam.nix** — `programs.steam.enable`, `programs.gamemode.enable`, `programs.gamescope.*`, `programs.mangohud.enable`
- **audio.nix** — PipeWire latency tweaks for gaming (lower buffer sizes)
- **performance.nix** — `powerManagement.cpuFreqGovernor`, disables `power-profiles-daemon`
- **sysctl.nix** — network and VM sysctl knobs (`net.core.netdev_max_backlog`, etc.)
- **systemd.nix** — CPU isolation and scheduling tweaks

## MangoHud

MangoHud is enabled globally. Launch any game with `MANGOHUD=1` or configure per-game in Steam launch options:

```
MANGOHUD=1 %command%
```

## Gamescope

capSysNice is enabled so Gamescope can set scheduler priorities without root. Usage:

```bash
gamescope -W 1920 -H 1080 -f -- %command%
```

## GameMode

GameMode daemon runs as a system service. Games using `libgamemode` or launched via `gamemoderun` get:
- CPU governor switched to `performance` while game runs
- `ioprio` class set to best-effort
- Nice level adjustment

## Steam

`programs.steam.enable` sets up the Steam FHS environment with 32-bit libraries and proper udev rules for controllers.

## Performance governor

`gaming-performance` preset sets `cpuFreqGovernor = "performance"` and disables the power profiles daemon to prevent it from resetting the governor. This is always active on omen (not just during gaming).

## Disable for non-gaming builds

If omen ever runs without the `gaming` role, the module flags simply won't be set and none of the gaming stack activates — the presets are purely additive.
