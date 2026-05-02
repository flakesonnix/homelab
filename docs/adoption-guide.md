# Adoption Guide

## Introduction

This document describes how to reuse the framework patterns from this repository in:

- a new repository
- an existing NixOS or Home Manager repository

The framework is based on four constraints:

- reusable logic lives in `lib/`
- user and host intent lives in `data/`
- host and home entrypoints remain thin
- validation is part of evaluation, not only CI

This document is intentionally conservative. It favors incremental adoption over large rewrites.

## Scope

The most reusable parts of this repository are:

- `lib/core/composition.nix`
- `lib/core/validation.nix`
- `lib/framework/package.nix`
- `lib/framework/resolve.nix`
- the `data/` layout for roles, presets, bundles, and package registries

The most repository-specific parts are:

- option namespaces such as `lucy.*`
- application helpers such as `niri.nix` and `waybar.nix`
- output paths passed to `applyHost` and `applyHome`
- the web UI export contract

## Suitability

This framework is suitable when the target repository has at least one of the following properties:

- multiple hosts with shared concerns
- multiple user profiles with overlapping bundles
- package selection spread across unrelated modules
- repeated feature clusters such as desktop, development, gaming, or server roles
- a need for validation of role, preset, bundle, and package references

This framework is usually unnecessary when the repository has a single host, minimal reuse, and no need for a data layer.

## Required Structure

A minimal repository layout is:

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

The `lib/` tree provides reusable functions.
The `data/` tree provides selections and metadata.
The `hosts/` and `home/` trees provide the thin evaluation entrypoints.

## New Repository

### Library Entry Point

Create a single library entrypoint.

Example:

```nix
let
  coreComposition = import ./core/composition.nix;
  coreValidation = import ./core/validation.nix;
  frameworkHost = import ./framework/host.nix;
  frameworkHome = import ./framework/home.nix;
  frameworkResolve = import ./framework/resolve.nix;
in {
  core = {
    composition = coreComposition;
    validation = coreValidation;
  };

  framework = {
    host = frameworkHost;
    home = frameworkHome;
    resolve = frameworkResolve;
  };
}
```

### Package Registries

Package definitions should move into registries before roles become large.

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

### Roles

Roles should describe reusable intent, not host-specific state.

Example:

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

Recommended initial role vocabulary:

- `core`
- `desktop`
- `dev`
- `gaming`
- `server`

### Host Entry Point

Host data should primarily select roles and carry local overrides.

Example host role selection:

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

### Home Entry Point

Home data should primarily select roles and, optionally, explicit bundle overrides.

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

### Validation

Validation should be added before the repository accumulates many roles or bundles.

The minimum useful checks are:

- missing role files
- missing preset files
- missing bundle files
- duplicate references
- invalid metadata
- invalid module flag paths
- unknown package toggles and tags

### Flake Checks

At minimum, define the following checks:

- formatting
- framework validation
- framework unit tests
- host evaluation

## Existing Repository

### Migration Strategy

Existing repositories should adopt the framework incrementally.

The recommended order is:

1. add `lib/`
2. add package registries
3. add role selection for one host
4. add role selection for one user
5. add validation
6. migrate one bundle or preset family at a time

### Package Selection First

Package registries are the least disruptive entry point.

They usually remove duplication immediately and establish the data model needed by later role and bundle work.

### Roles as Selectors

Roles do not need to replace existing modules.

In an existing repository, roles may act only as selectors for:

- presets
- package tags
- module flags

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

This allows the framework to sit on top of an existing module structure.

### Bundle Migration

Home Manager bundles should be migrated gradually.

Recommended order:

1. shell and CLI tools
2. editor configuration
3. desktop applications
4. graphical integrations
5. renderer-backed configuration such as CSS or KDL

### Stable Entry Points

Existing `hosts/<name>/default.nix` and `home/<user>/default.nix` entrypoints should usually remain stable.

Only their internals should change to call the framework helpers.

This reduces review noise and keeps the migration localized.

### Explicit Bundle Overrides

`data/home/<user>/bundles.nix` is useful as a migration bridge.

It is appropriate when:

- a user profile should temporarily differ from role-derived bundle resolution
- only part of the repository has been migrated to role-driven bundles

It should not replace role design entirely.

## Minimal Adoption Path

For a repository that only needs the smallest useful subset, the following is sufficient:

1. `lib/core/composition.nix`
2. `lib/core/validation.nix`
3. package registries
4. `data/roles/`
5. one host role selection
6. one home role selection
7. flake checks

This is enough to get validation and structured selection without adopting every helper in this repository.

## Copy Versus Adapt

The following files are usually suitable for direct reuse with minimal renaming:

- `lib/core/composition.nix`
- `lib/core/validation.nix`
- `lib/framework/resolve.nix`
- `lib/framework/package.nix`

The following files usually require adaptation to local paths and output namespaces:

- `lib/framework/host.nix`
- `lib/framework/home.nix`

The following pieces should remain project-specific:

- option namespaces such as `lucy.*`
- output paths such as `["lucy" "programs"]`
- application helpers such as `niri.nix` and `waybar.nix`
- export formats intended for the web UI

## Common Errors

Common migration errors include:

- introducing roles before package registries exist
- storing large handwritten text blocks in roles and bundles
- placing host-specific behavior into shared roles without a preset boundary
- deduplicating too early and hiding duplicate-reference validation
- validating only in CI and not in the actual apply path

## Related Pages

- `docs/framework.md`
- `docs/data-model.md`
- `README.md`
