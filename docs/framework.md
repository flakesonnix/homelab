# Framework

This repo is moving toward a self-hosted Nix framework.

## Layers

- `lib/`: reusable helpers, renderers, and framework constructors
- `data/`: declarative registries for packages and bundles
- `modules/`: NixOS and Home Manager modules that consume framework data
- `hosts/`: host-specific composition
- `home/lucy/`: user-specific composition

## Current Registries

- `data/packages/system.nix`: NixOS-side package toggle registry
- `data/packages/home.nix`: Home Manager package toggle registry
- `data/bundles/*.nix`: bundle data consumed by thin Home Manager wrappers

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
- `lib/framework/niri.nix`: Niri-oriented config constructors
- `lib/framework/waybar.nix`: Waybar-oriented config constructors

## Next Steps

- convert more Home Manager bundles to pure data
- move host declarations into `data/hosts/`
- expand gaming presets for `omen`
- render `niri` and `waybar` from more structured data
