---
aliases: [Flake, CI, Topology]
tags: [reference, nixos]
type: reference
---

# Flake · CI · topology

[[Home|← Home]]

## Inputs (16)

`nixpkgs/nixos-unstable`, `home-manager/master`, `stylix`, `wrappers/lassulus`, `nix-flatpak`, `sops-nix`, `flake-parts`, `nixos-hardware`, `nixGaming/fufexan`, `lanzaboote`, `run0-sudo-shim`, `yammat/gitea.c3d2`, `deploy-rs`, `microvm.nix`, `nix-topology/oddlama` and the pinned `ewm` tarball. EWM keeps its own nixpkgs; the other follows relationships are defined in `flake.nix`. nix-topology is unpatched; label overlap is handled by `fix-network-svg` post-processing in `packages.topology`.

Custom outputs (the warning is expected and fine): `deploy`, `topology`, `nixfleetArtifacts`.

## Configurations

The root flake exports only `nixosConfigurations.p53` (desktop + Lanzaboote +
Home Manager) and `nixosConfigurations.mireo` (router/server + microVM host).
Deploy nodes are p53 → localhost and mireo → `10.8.0.1` (remote build enabled).
nyagate is retired; there is no root live-ISO configuration. The optional Xfce
PXE installer is a package, not a deploy target. `nixbsd/` is a separate
experimental flake with its own lockfile; see `nixbsd/README.md`.

perSystem: `formatter` wraps RFC 166 `nixfmt` for tracked non-generated source;
devShell includes nixfmt/statix/nix-tree/go/nodejs_22/just/fzf.
`topology.modules=[topology.nix]`; packages: `full-ci-checks`, `topology`,
`nixfleet-api/agent/web/manifest/ui`, `nixfleet` CLI, `dwl-scroll`, `lucy-ca`,
`pxe-desktop-boot`. App names are unchanged; their definitions live in
`flake/apps.nix`. The optional PXE build is in `hosts/pxe-desktop/boot.nix`.
See `CONTRIBUTING.md` for RFC scope and repository conventions.

Exported NixOS modules: `nixos`, `home`, `dwl-scroll`, `lucy-ca`. The dwl checks
cover the default/no-Xwayland packages, opt-in module behavior, headless runtime
and typed settings/keymaps. They are included in `full-ci-checks`.

## CI (`.github/workflows/ci.yml`, 6 jobs, push to master + PR, cancel-in-progress)

- `check-light` — eval formatter/devShell/apps + build formatting/repository-tooling checks
- `check-full` — `nix build .#full-ci-checks`
- `eval` — p53 toplevel eval
- `nixfleet` — Go + frontend tests
- `nixfleet-manifest` — master only, commits `artifacts/{manifest,ui}.json`
- `topology` — master only, commits `docs/topology/{main,network}.svg`

## Topology

```bash
nix build .#topology
ls result/  # main.svg network.svg (fix-network-svg chmod+fix)
```

Config: `topology.nix` + `modules/nixos/topology.nix` (`lucy.topology.*` → nix-topology).
