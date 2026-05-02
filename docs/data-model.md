# Data model

## Overview

The framework is data-first.

The library decides how to load, validate, and merge data.
The `data/` tree describes what a host or user wants enabled.

## Package registries

Package registries live under `data/packages/`.

Current files:

- `data/packages/system.nix`
- `data/packages/home.nix`

Expected shape:

```nix
{
  firefox = {
    description = "Firefox browser";
    targets = ["system" "home"];
    tags = ["browser" "desktop"];
    packages = {
      system = [pkgs.firefox];
      home = [];
    };
  };
}
```

Used by:

- `lib/framework/package.nix`
- `lib/core/validation.nix`

## Roles

Role declarations live under `data/roles/`.

Each role may define `meta`, `host`, and `home` sections.

Typical shape:

```nix
{
  meta = {
    description = "Desktop role";
    targets = ["host" "home"];
    requires = {
      home = ["core"];
    };
    conflicts = {
      host = ["server"];
    };
  };

  host = {
    presets = ["desktop-base"];
    moduleFlags = {
      lucy.desktop.enable = true;
    };
    packageTags = ["desktop"];
  };

  home = {
    bundles = ["desktop"];
    packageToggles = ["nautilus"];
  };
}
```

Notes:

- `meta.description` should be a non-empty string.
- `meta.targets` must include the context where the role is used.
- `host.presets` are merged with direct host preset selections.
- `home.bundles` are used only when no explicit home bundle override is set.

## Presets

Preset declarations live under `data/presets/`.

Typical shape:

```nix
{
  meta = {
    description = "Gaming performance baseline";
    targets = ["host"];
  };

  moduleFlags = {
    lucy.gaming.enable = true;
  };

  packageTags = ["gaming"];
}
```

Used by:

- `lib/framework/host.nix`
- `lib/framework/resolve.nix`
- `lib/core/validation.nix`

## Bundles

Bundle declarations live under `data/bundles/`.

Typical shape:

```nix
{
  meta = {
    description = "Core user environment";
    targets = ["home"];
  };

  moduleFlags = {
    programs.bash.enable = true;
  };

  packageToggles = ["comma" "manix"];

  programs = { ... };
  services = { ... };
  home = { ... };
  xdg = { ... };
  nix = { ... };
}
```

Used by:

- `lib/framework/home.nix`
- `lib/framework/bundle.nix`
- `lib/core/validation.nix`

## Host data

Host declarations live under `data/hosts/<host>/`.

Common files:

- `roles.nix`
- `presets.nix`
- `module-flags.nix`
- `packages.nix`
- `services.nix`
- `power.nix`
- `settings.nix`

Important rules:

- `roles.nix` is the main host role selection.
- `presets.nix` adds direct host preset selections.
- direct host presets are merged with role-derived presets.

Example `roles.nix`:

```nix
[
  "desktop"
  "gaming"
]
```

Example `presets.nix`:

```nix
[
  "gaming-performance"
]
```

## Home data

Home declarations live under `data/home/<user>/`.

Common files:

- `roles.nix`
- `bundles.nix`
- `module-flags.nix`
- `settings.nix`

Important rules:

- `roles.nix` selects home roles.
- `bundles.nix` is an explicit override for role-derived bundles.
- when `bundles.nix` is empty or missing, role-derived bundles are used.

Example `roles.nix`:

```nix
[
  "core"
  "desktop"
  "dev"
]
```

Example `bundles.nix`:

```nix
[
  "core"
  "desktop"
]
```

## Merge semantics

The framework uses two main merge styles:

- attr fields are merged with recursive update
- list fields are concatenated, then selected paths may be deduplicated later

Current examples:

- `lib/core/composition.nix` merges `moduleFlags`, `settings`, `programs`, `services`, `xdg`, `home`, and `nix`
- `lib/framework/resolve.nix` deduplicates resolved preset and bundle names

## Rendering boundary

Structured data should stay structured until the final output step.

Renderers live under `lib/render/`:

- `command.nix`
- `kdl.nix`
- `css.nix`

Rule of thumb:

- prefer attrsets and lists in `data/` and `lib/`
- prefer render helpers over large handwritten string blobs

## Related pages

- `docs/framework.md`
- `docs/adoption-guide.md`
- `README.md`
