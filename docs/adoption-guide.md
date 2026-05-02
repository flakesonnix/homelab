# Adoption guide

## Overview

This page explains how to reuse the framework patterns from this repository in:

- a new project
- an existing NixOS or Home Manager project

The intended outcome is not to copy this repository exactly.
The intended outcome is to adopt the model:

- keep logic in `lib/`
- keep intent in `data/`
- keep host and user wrappers thin
- keep validation close to the apply path

## Before you start

This framework is a good fit when:

- you manage more than one concern through shared roles or presets
- you want host and home selections to be declarative data
- you want validation for roles, bundles, presets, and package refs
- you want to render config from structured data instead of large handwritten blobs

It is probably too much if:

- you have one host and no shared abstractions
- your configuration is still changing faster than the abstractions
- you do not want an opinionated `data/` tree

## Core ideas to keep

The useful parts of this repository are:

### `lib/core`

- composition helpers
- validation helpers
- small attr and list utilities

### `lib/framework`

- host loading and apply helpers
- home loading and apply helpers
- role preset and bundle resolution
- export helpers for tooling and UI

### `data/`

- package registries
- roles
- presets
- bundles
- host data
- home data

## Option 1: New project

### 1. Create the basic layout

Start with:

```text
.
├── flake.nix
├── lib/
├── data/
│   ├── roles/
│   ├── presets/
│   ├── bundles/
│   ├── packages/
│   ├── hosts/
│   └── home/
├── modules/
│   ├── nixos/
│   └── home/
├── hosts/
└── home/
```

### 2. Add a library entrypoint

Create a small `lib/default.nix` that exports your helpers.

Minimal example:

```nix
let
  coreComposition = import ./core/composition.nix;
  coreValidation = import ./core/validation.nix;
  frameworkHost = import ./framework/host.nix;
  frameworkHome = import ./framework/home.nix;
in {
  core = {
    composition = coreComposition;
    validation = coreValidation;
  };

  framework = {
    host = frameworkHost;
    home = frameworkHome;
  };
}
```

### 3. Move package definitions into registries

Instead of enabling packages directly inside modules, define them in `data/packages/*.nix`.

Example:

```nix
{pkgs}: {
  firefox = {
    description = "Firefox browser";
    targets = ["system" "home"];
    tags = ["browser" "desktop"];
    packages.system = [pkgs.firefox];
  };
}
```

### 4. Define roles first, not hosts first

A good first role split is:

- `core`
- `desktop`
- `dev`
- `gaming`
- `server`

Example role:

```nix
{
  meta = {
    description = "Desktop role";
    targets = ["host" "home"];
  };

  host = {
    presets = ["desktop-base"];
    packageTags = ["desktop"];
  };

  home = {
    bundles = ["desktop"];
  };
}
```

### 5. Keep host data thin

Your host data should mostly select roles, plus host-local overrides.

Example `data/hosts/my-host/roles.nix`:

```nix
[
  "core"
  "desktop"
  "dev"
]
```

Example host wrapper:

```nix
{
  lib,
  pkgs,
  ...
}: let
  dot = import ../../lib;
  packageRegistry = import ../../data/packages/system.nix {inherit pkgs;};
  hostData = dot.framework.host.loadHostDirectory {
    inherit lib;
    root = ../../data/hosts/my-host;
    args = {inherit pkgs;};
  };
in {
  config = dot.framework.host.applyHost {
    inherit lib;
    host = hostData;
    roleRoot = ../../data/roles;
    presetRoot = ../../data/presets;
    inherit packageRegistry;
    packagePath = ["myNamespace"];
    basePackagePath = ["environment" "systemPackages"];
  };
}
```

### 6. Keep home data thin

Example home wrapper:

```nix
{
  lib,
  pkgs,
  ...
}: let
  dot = import ../../lib;
  packageRegistry = import ../../data/packages/home.nix {inherit pkgs;};
  homeData = dot.framework.home.loadHomeDirectory {
    inherit lib;
    root = ../../data/home/alice;
    args = {inherit pkgs;};
  };
in {
  config = dot.framework.home.applyHome {
    inherit lib;
    home = homeData;
    roleRoot = ../../data/roles;
    bundleRoot = ../../data/bundles;
    inherit packageRegistry;
    packagePath = ["myNamespace" "programs"];
  };
}
```

### 7. Add validation early

Do not wait until the framework is large.

At minimum, validate:

- missing role files
- missing preset files
- missing bundle files
- invalid metadata
- duplicate references
- invalid module flag paths
- unknown package toggles and tags

### 8. Add checks in `flake.nix`

Start with:

- formatting
- one framework validation check
- one framework unit check
- one host evaluation check

## Option 2: Existing project

The safest migration is incremental.

### 1. Do not rewrite everything at once

Start by wrapping existing behavior instead of replacing it.

Good first moves:

- add `lib/`
- add `data/packages/`
- move one host to `data/hosts/<name>/roles.nix`
- move one cluster of user config into one bundle

### 2. Move package selection before module structure

This is usually the easiest migration step.

Replace scattered package lists with a registry plus toggles and tags.

That gives you immediate wins:

- less duplication
- easier validation
- easier role reuse

### 3. Introduce roles as selectors, not as full rewrites

If your repo already has big modules, keep them.
Make roles point at them through presets, package tags, and module flags.

Example:

```nix
{
  meta = {
    description = "Developer workstation";
    targets = ["host"];
  };

  host = {
    moduleFlags = {
      my.dev.enable = true;
    };
    packageTags = ["dev"];
  };
}
```

This lets you layer the framework on top of the old module layout.

### 4. Migrate one home bundle at a time

Do not convert every Home Manager module into bundle data at once.

A safe migration order is:

1. shell and CLI tools
2. editor configuration
3. desktop applications
4. graphical service integrations
5. renderer-backed config like CSS or KDL

### 5. Keep old wrappers, change their internals

If your repo already has `hosts/<name>/default.nix` or `home/<user>/default.nix`, keep those entrypoints stable.

Only switch their implementation to call the framework helpers.

That reduces blast radius and makes review easier.

### 6. Add validation before aggressive refactors

Once roles, presets, or bundles exist, add validation immediately.

This prevents subtle drift like:

- role names that no longer exist
- bundle names that were renamed
- bad module flag paths
- invalid metadata targets

### 7. Use explicit bundle overrides sparingly

`data/home/<user>/bundles.nix` is useful for temporary overrides or curated home profiles.

Use it when:

- you want a smaller or larger user profile than roles would derive
- you are migrating gradually and need a manual bridge

Avoid leaning on it for everything, or the roles stop being useful.

## Minimal migration path

If you want the shortest useful path in an existing project, do this:

1. add `lib/core/composition.nix`
2. add `lib/core/validation.nix`
3. add package registries
4. add `data/roles/`
5. make one host read `data/hosts/<name>/roles.nix`
6. make one user read `data/home/<user>/roles.nix`
7. add `flake check` coverage

That is enough to get value without committing to every helper in this repository.

## What to copy directly

Usually worth copying with only light renaming:

- `lib/core/composition.nix`
- `lib/core/validation.nix`
- `lib/framework/resolve.nix`
- `lib/framework/package.nix`

Copy more carefully:

- `lib/framework/host.nix`
- `lib/framework/home.nix`

These are more tied to this repository's data shape and output paths.

## What to adapt, not copy

Project-specific details should stay project-specific:

- option namespaces like `lucy.*`
- output paths like `["lucy" "programs"]`
- app-specific helpers like `niri.nix` and `waybar.nix`
- web UI export shape if you do not need the UI

## Common mistakes

- moving everything into roles before package registries exist
- storing too much handwritten text in roles and bundles
- hiding important differences inside giant bundle files
- deduplicating too early and losing duplicate-reference validation
- validating only in CI and not in the actual apply path

## Suggested adoption order

For a new project:

1. package registries
2. roles
3. presets and bundles
4. host/home apply helpers
5. validation
6. renderer cleanup
7. optional UI or export tooling

For an existing project:

1. package registries
2. one host role selection
3. one home role selection
4. validation
5. gradual bundle migration
6. gradual preset migration

## Related pages

- `docs/framework.md`
- `docs/data-model.md`
- `README.md`
