# Data Model

This repo is moving toward a data-first framework shape.

## Package Registries

Package registries live under `data/packages/`.

Current files:

- `data/packages/system.nix`
- `data/packages/home.nix`

Each entry follows this shape:

```nix
{
  description = "Human description";
  targets = ["system" "user" "home"];
  packages = {
    system = [ ... ];
    user = [ ... ];
    home = [ ... ];
  };
  tags = ["desktop" "dev"];
}
```

## Bundle Registries

Bundle data lives under `data/bundles/`.

Current files:

- `data/bundles/core.nix`
- `data/bundles/desktop.nix`
- `data/bundles/dev.nix`

Bundle shape:

```nix
{
  moduleFlags = {
    lucy.shell.enable = true;
  };

  packageToggles = ["comma" "manix"];

  programs = { ... };
  services = { ... };
  home = { ... };
  nix = { ... };
  xdg = { ... };
}
```

Thin wrappers in `home/lucy/bundles/` apply these through `lib/framework/bundle.nix`.

## Host Data

Host declarations live under `data/hosts/`.

Current files:

- `data/hosts/omen.nix`

Host shape:

```nix
{
  presets = ["gaming-base" "gaming-steam"];
  moduleFlags = { ... };
  packageToggles = [ ... ];
  basePackages = [ ... ];
  settings = { ... };
}
```

Thin wrappers in `hosts/<name>/host.nix` apply host data through `lib/framework/host.nix`.

## Preset Data

Preset declarations live under `data/presets/`.

Current files:

- `data/presets/gaming-base.nix`
- `data/presets/gaming-steam.nix`

Preset shape:

```nix
{
  moduleFlags = {
    lucy.gaming.enable = true;
  };
}
```

Presets are merged before host-local settings so a host can build up larger behavior from smaller fragments.

## Renderers

Renderers live under `lib/render/`.

Current files:

- `lib/render/command.nix`
- `lib/render/kdl.nix`
- `lib/render/css.nix`

Rule of thumb:

- keep data as attrs/lists as long as possible
- only render to strings at the config-file boundary

## Current Limit

The repo is not string-free yet. It is only moving strings toward:

- atomic symbols in `lib/symbols.nix`
- renderer functions
- unavoidable external config values

Large handwritten config blobs should keep shrinking over time.
