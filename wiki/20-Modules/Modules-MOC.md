---
aliases: [Modules, Modules overview]
tags: [moc, module]
type: moc
---

# Modules overview

[[Home|← Home]]

```dataview
TABLE namespace AS Namespace
FROM "wiki/20-Modules"
WHERE type = "module"
SORT file.name ASC
```

- [[20-Modules/NixOS-Modules|NixOS modules table]] — all 24 + gaming/6
- [[20-Modules/Home-Modules|Home modules]] — niri, waybar, stylix, ssh, opencode, dunst
- [[20-Modules/Gaming-Stack|Gaming stack]] — presets → submodules
- NixFleet module: see [[50-NixFleet/Manifest-API|Manifest & API]] (`lucy.nixfleet.*`)

> Modules are **not** auto-imported — `flake.nix` lists explicitly per host. Source: `docs/modules.md`, `modules/nixos/default.nix`, `modules/home/default.nix`.
