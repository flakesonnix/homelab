---
aliases: [Data model]
tags: [nixos, reference]
type: reference
---

# Data model (`data/` + `lib/framework`)

[[Home|← Home]] · Source `docs/data-model.md`.

> Hosts describe **what they are**, not giant piles of unrelated options.

```
data/
├── roles/core.nix desktop.nix dev.nix gaming.nix llm.nix
├── bundles/core.nix desktop.nix dev.nix
├── presets/gaming-base.nix gaming-performance.nix gaming-steam.nix
├── packages/system.nix home.nix   # tagged registries
├── hosts/x270/{settings,roles,module-flags,packages,power,services}.nix
├── hosts/mireo/settings.nix       # server, no roles.nix (intentionally [])
├── hosts/nyagate/{settings,packages}.nix
└── home/lucy/{roles,bundles,settings}.nix
```

The framework `lib/framework` (`frameworkLib`, `applyHost`/`applyHome` in `hosts/*/host.nix:17`, `home/lucy/default.nix:40`) + types in `lib/types.nix` resolves everything at eval time.

## Flow

`roles.nix` → load role definitions → `host.moduleFlags` + `packageTags` + `presets` + `home.bundles` → merge with `settings.nix`/`module-flags.nix`/`packages.nix` → NixOS/HM config.

## Per-host / per-user files

| File | Purpose |
|------|---------|
| `settings.nix` | NixOS config merged directly (hostname, boot, network…) |
| `roles.nix` | `[desktop dev gaming]` (x270) / intentionally absent (mireo, nyagate → `[]`) |
| `module-flags.nix` | Extra flags beyond roles |
| `packages.nix` / `services.nix` / `power.nix` | Extra packages/services/power |
| `home/lucy/{roles,bundles,settings}.nix` | `[core desktop dev]` + extra bundles + overrides |

Next: [[30-Data-Model/Roles-Bundles-Presets|Roles → bundles + presets]].
