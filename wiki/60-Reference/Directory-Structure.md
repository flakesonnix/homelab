---
aliases: [Directory structure, Repo layout]
tags: [reference]
type: reference
---

# Directory structure

[[Home|← Home]]

```
flake.nix            # 16 inputs, 4 configs (x270/mireo/nyagate/live) + 3 deploy nodes
profiles/base.nix desktop.nix
hosts/<host>/default.nix host.nix hardware.nix
modules/nixos/*.nix (24) + gaming/ (6)
modules/home/*.nix (6) + default.nix
home/lucy/default.nix + editor/git/shell + programs/ (14) + keys/ + cursors/ + wallpapers/
data/                # declarative model
  home/lucy/ roles bundles presets packages/ lib/ nixfleet/ tests/ docs/
lib/framework (applyHost/applyHome) types docs topology-fixer ci waybar-scripts
nixfleet/Go api/agent/web + manifest.nix → artifacts/manifest+ui.json
tests/dotfiles-tests + topology-unit + builders-unit + nixfleet
docs/hosts modules data-model secrets printing gaming-x270 apt-cache audio-latency nfs-ubuntu-client topology/*.svg
wiki/                # ← this vault (Obsidian)
justfile nix-settings.nix topology.nix patches/nix-topology-spacing.patch scripts/new-host.sh
```

Framework entry points: `hosts/*/host.nix:17`, `home/lucy/default.nix:40`. No external rivotril.
