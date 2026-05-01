# Framework

This repo is moving toward a self-hosted Nix framework.

## Layers

- `lib/`: reusable helpers, renderers, and framework constructors
- `data/`: declarative registries for packages and bundles
- `modules/`: NixOS and Home Manager modules that consume framework data
- `hosts/`: host-specific composition
- `home/lucy/`: user-specific composition

## Current Registries

- `data/packages/system.nix`: system package registry (toggles + tags)
- `data/packages/home.nix`: home package registry (toggles + tags)
- `data/bundles/*.nix`: home bundles (data-first)
- `data/hosts/<host>/*.nix`: host declarations split by concern
- `data/presets/*.nix`: reusable preset fragments
- `data/roles/*.nix`: shared role vocabulary (each role may have `host` and/or `home` sections)

## Renderer Direction

The long-term rule is:

- represent config as Nix attrs/lists first
- render KDL/CSS/command text only at the final file boundary

Current foundation:

- `lib/render/command.nix`
- `lib/render/kdl.nix`
- `lib/render/css.nix`

## Framework Helpers

- `lib/framework/package.nix`: package registry option and routing helpers
- `lib/framework/bundle.nix`: bundle application helpers
- `lib/framework/host.nix`: host application and preset merge helpers
- `lib/framework/niri.nix`: Niri-oriented config constructors
- `lib/framework/waybar.nix`: Waybar-oriented config constructors

## Host Flow

Current host composition:

- `data/hosts/omen/`: declarative host data (roles, flags, packages, services, power, settings)
- `hosts/omen/host.nix`: thin wrapper that applies host data through `lib/framework/host.nix`

Roles expand to presets/module flags/package tags, then host-local data overlays.

## Next Steps

- convert more Home Manager bundles to pure data
- add more preset categories beyond gaming
- render `niri` and `waybar` from more structured data
- document data schemas in more detail
