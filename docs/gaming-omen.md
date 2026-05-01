# Omen Gaming

`omen` is the main gaming host in this repo.

## Current Stack

Gaming defaults are enabled via `gaming` role + presets.

Current features:

- Steam enabled
- SteamOS-style platform optimizations enabled
- GameMode enabled
- Gamescope enabled
- MangoHud installed
- PipeWire low-latency tuning enabled through `nix-gaming`

## Where It Lives

- Host declaration: `data/hosts/omen/` (roles + host-local overlays)
- Roles: `data/roles/gaming.nix`
- Presets: `data/presets/gaming-*.nix`
- Host application: `hosts/omen/host.nix`
- Gaming modules: `modules/nixos/gaming/*.nix`

## Tuning Defaults

Current audio defaults:

- `quantum = 64`
- `rate = 48000`

These are applied through `services.pipewire.lowLatency` when `lucy.gaming.enable = true`.

## Notes

- `mangohud` is currently installed as a package rather than enabled through a NixOS module option.
- `nix-gaming` is used for the low-latency PipeWire and platform optimization modules.
- `nixos-hardware` generic laptop/Intel/SSD profiles are applied to `omen`; there is no exact upstream profile for this HP Omen model.

## Follow-Up Ideas

- Add a streaming subfeature for Sunshine or OBS.
- Add streaming subfeature (Sunshine / OBS) as role or preset.
- Add game-specific launch helpers if needed.
