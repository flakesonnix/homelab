# Omen Gaming

`omen` is the main gaming host in this repo.

## Current Stack

Gaming defaults are enabled through `lucy.gaming` in `data/hosts/omen.nix`.

Current features:

- Steam enabled
- SteamOS-style platform optimizations enabled
- GameMode enabled
- Gamescope enabled
- MangoHud installed
- PipeWire low-latency tuning enabled through `nix-gaming`

## Where It Lives

- Host declaration: `data/hosts/omen.nix`
- Host application: `hosts/omen/host.nix`
- Gaming module: `modules/nixos/gaming.nix`

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
- Move gaming toggles into preset data under `data/presets/`.
- Add game-specific launch helpers if needed.
