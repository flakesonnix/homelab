# Working on this repository

## Layout

- `flake.nix` wires inputs, hosts, packages, checks and deploy targets together.
  CLI app definitions live in `flake/apps.nix`; the optional installer build
  lives beside its configuration in `hosts/pxe-desktop/boot.nix`.
- `hosts/` and `profiles/` compose NixOS modules; `home/` composes Home Manager.
- `data/` holds roles, bundles, presets and declarative host/service settings.
- `modules/` defines configurable features; `lib/` contains reusable helpers.
- `pkgs/<name>/` keeps local package code and support files together.
- `tests/` contains repository/module/integration checks.
- `nixfleet/` owns its Go API/agent/CLI, frontend, packaging and generated metadata.
- `nixbsd/` is an independent experimental flake. Keep its inputs/lockfile isolated
  and follow its [disk-safety instructions](nixbsd/README.md).
- `docs/` is the detailed reference; `wiki/` is its Obsidian navigation layer.

## Nix conventions and official RFCs

This repository opts into the standard format from accepted
[RFC 166](https://github.com/NixOS/rfcs/blob/master/rfcs/0166-nix-formatting.md),
using `nixfmt` pinned by the root `flake.lock`. Neovim's Nix formatter uses the
same tool. `.editorconfig` supplies the basic whitespace conventions.

```sh
nix develop
just fmt
just fmt-check
just check-light
nix build .#checks.x86_64-linux.formatting .#checks.x86_64-linux.repository
```

Formatting only visits tracked Nix source below the current directory. It skips
symlinks and generated `hardware-configuration.nix` files, and does not traverse
private or untracked build/vendor directories. Stage new source paths with
`git add -N <path>` before flake evaluation or formatting. Do not stage secrets.

Following the opt-in package testing convention in accepted
[RFC 119](https://github.com/NixOS/rfcs/blob/master/rfcs/0119-testing-conventions.md),
NixFleet's Go packages expose the shared unit suite as `passthru.tests.unit`:

```sh
nix build .#nixfleet-api.tests.unit
nix build .#nixfleet-web
just check-full
```

Keep cheap package tests in `checkPhase`; expose downstream/integration checks
separately when appropriate. `checks` remains the flake's CI entry point.
Add regression coverage for functional changes, not just successful evaluation.

[RFC 140](https://github.com/NixOS/rfcs/blob/master/rfcs/0140-simple-package-paths.md)
defines `pkgs/by-name/<shard>/<name>/package.nix` **inside nixpkgs**. It does not
mandate a directory layout for NixOS configurations. This small repository keeps
its existing local package directories rather than adding unnecessary shards.

## Safety and generated output

- Rebuild/deploy commands activate real machines. Tests and formatting do not
  authorize deployment, partitioning, service enrollment or secret rotation.
- Preserve public flake output names and existing uncommitted work during cleanup.
- Never commit private keys or plaintext credentials. Public CA certificates and
  SSH public keys are not private keys; see [secrets](docs/secrets.md).
- Change the Nix sources for NixFleet metadata and topology diagrams, not their
  generated JSON/SVG copies. CI refreshes those artifacts.
- Keep build products outside source directories or ignored; do not delete
  unfamiliar files merely because they are untracked.
