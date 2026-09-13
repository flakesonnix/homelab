---
aliases: [Flake, CI, Topology]
tags: [reference, nixos]
type: reference
---

# Flake · CI · topology

[[Home|← Home]]

## Inputs (16)

`nixpkgs/nixos-unstable`, `home-manager/master`, `stylix`, `wrappers/lassulus`, `nix-flatpak`, `sops-nix`, `flake-parts`, `nixos-hardware`, `nixGaming/fufexan`, `nur`, `lanzaboote`, `run0-sudo-shim`, `yammat/gitea.c3d2`, `deploy-rs`, `microvm.nix`, `nix-topology/oddlama` (+ patch `patches/nix-topology-spacing.patch`).

Custom outputs (the warning is expected and fine): `deploy`, `topology`, `nixfleetArtifacts`.

## Configurations

`x270-config` (desktop + 14 modules + lanzaboote + HM), `mireo-config` (base + microvm host + cups + nixfleet + sops), `nyagate-config` (base + sops), `live-config` (installer ISO, fonts/niri/waybar/hm-base).

perSystem: `formatter=alejandra`, devShell (alejandra/statix/nix-tree/go/nodejs_22/just/fzf), `topology.modules=[topology.nix]`, packages (`full-ci-checks`, `topology-fixed`, `nixfleet-api/agent/cli/web/manifest/ui`, `live-iso`), apps (`rebuild/check/light/full/update/deploy-*/setup-sops/nixfleet/manifest/menu`).

## CI (`.github/workflows/ci.yml`, 6 jobs, push to master + PR, cancel-in-progress)

- `check-light` — eval formatter/devShell/apps
- `check-full` — `nix build .#full-ci-checks`
- `eval` — x270 toplevel eval
- `nixfleet` — Go + frontend tests
- `nixfleet-manifest` — master only, commits `artifacts/{manifest,ui}.json`
- `topology` — master only, commits `docs/topology/{main,network}.svg`

## Topology

```bash
nix build .#topology
ls result/  # main.svg network.svg (fix-network-svg chmod+fix)
```

Config: `topology.nix` + `modules/nixos/topology.nix` (`lucy.topology.*` → nix-topology).
