# Framework

## Overview

This repository is built around a small Nix library plus declarative data.

The high-level goal is:

- keep reusable logic in `lib/`
- keep machine and user intent in `data/`
- keep modules thin
- render text formats only at the final boundary

## Directory layout

- `lib/`
  Reusable helpers, renderers, validation, and framework entrypoints.
- `data/`
  Roles, presets, bundles, package registries, and host/home selections.
- `modules/`
  NixOS and Home Manager modules that consume the framework output.
- `hosts/`
  Host wrappers that apply `data/hosts/<name>` through the library.
- `home/`
  User wrappers and program modules.

## Library layout

### `lib/core`

Low-level helpers used by the framework.

- `attrs.nix`
  Small attrset helpers.
- `lists.nix`
  Small list helpers.
- `composition.nix`
  Merge and rendering helpers for attr/list based config parts.
- `registry.nix`
  Package registry lookups.
- `package-routing.nix`
  Routing helpers for package registries.
- `toggles.nix`
  Toggle helpers.
- `validation.nix`
  Framework validation for roles, presets, bundles, package refs, and module flags.

### `lib/framework`

Framework-level helpers for applying host and home data.

- `host.nix`
  Loads host data, resolves role presets, validates the result, and renders package enables.
- `home.nix`
  Loads home data, resolves bundles, validates the result, and renders package enables.
- `resolve.nix`
  Shared resolution helpers for role-derived presets and bundles.
- `package.nix`
  Package toggle and tag selection helpers.
- `bundle.nix`
  Bundle composition helpers.
- `preset.nix`
  Preset composition helpers.
- `export.nix`
  Structured metadata and preview export for the web UI.
- `actions.nix`, `keys.nix`, `niri.nix`, `waybar.nix`
  Focused helpers for action wiring and app-specific config generation.

### `lib/render`

Renderers for string output.

- `command.nix`
- `kdl.nix`
- `css.nix`

Rule of thumb:

- represent config as attrs and lists first
- render strings only when writing the final file format

## Data flow

### Host flow

1. `data/hosts/<name>/roles.nix` selects host roles.
2. `lib/framework/host.nix` loads the matching role `host` sections.
3. `lib/framework/resolve.nix` resolves direct and role-derived presets.
4. `lib/core/validation.nix` validates roles, presets, package refs, and module flag paths.
5. The merged result is rendered into NixOS option attrs.

### Home flow

1. `data/home/<user>/roles.nix` selects home roles.
2. `data/home/<user>/bundles.nix` may override role-derived bundle selection.
3. `lib/framework/home.nix` loads the matching role `home` sections.
4. `lib/framework/resolve.nix` resolves the final bundle list.
5. `lib/core/validation.nix` validates roles, bundles, package refs, and module flag paths.
6. The merged result is rendered into Home Manager option attrs.

## Public entrypoints

The main entrypoint is `lib/default.nix`.

Important exported attrs:

- `dot.core.composition`
- `dot.core.validation`
- `dot.framework.host`
- `dot.framework.home`
- `dot.framework.resolve`
- `dot.framework.export`
- `dot.render.kdl`
- `dot.render.css`

Example:

```nix
let
  dot = import ../lib;
in
  dot.framework.resolve.resolveHomeBundles {
    directBundles = ["manual"];
    roles = [
      {bundles = ["core"];}
      {bundles = ["desktop"];}
    ];
  }
```

## Validation model

`lib/core/validation.nix` checks:

- missing role, preset, and bundle files
- duplicate role, preset, and bundle references
- missing metadata blocks
- invalid metadata descriptions or targets
- unknown package toggles and tags
- unknown role requirements and conflicts
- selected roles that violate `requires` or `conflicts`
- conflicting module flag values across merged parts
- invalid module flag paths

Validation is not only a `flake check` concern.
It is also wired into the real host and home apply paths.

## Web UI integration

The web UI reads framework data from `lib/framework/export.nix`.

That export provides:

- metadata for roles, presets, and bundles
- resolved preview data for host roles, host presets, home roles, and home bundles

This keeps the UI driven by Nix as the source of truth instead of duplicating metadata in Rust.

## Related pages

- `docs/data-model.md`
- `docs/adoption-guide.md`
- `docs/secrets.md`
- `docs/gaming-omen.md`
