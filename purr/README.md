# Purr — declarative Nix DSL (Zig compiler)

Purr compiles `.purr` → deterministic Nix for NixOS/Home Manager. See `../README.md` (Purr section) and `../docs/purr/design.md` for language design & pipeline.

## Quick start

```bash
nix develop          # zig 0.16 + alejandra
zig build            # builds zig-out/bin/purr + purrc
zig build test       # 35 tests (lexer/parser/semantic/nix + golden + check --json)
bash tests/e2e.sh    # E2E: .purr -> Nix -> alejandra + import edge cases + check --json

# check / compile (with meow.purr project entry)
./zig-out/bin/purr check meow.purr
./zig-out/bin/purr check --json        # uses meow.toml → meow.purr, stdout JSON
./zig-out/bin/purr check               # auto meow.purr discovery (cwd→parents)
./zig-out/bin/purr compile examples/minimal.purr --out /tmp/out.nix
./zig-out/bin/purr compile examples/hosts/x270.purr --out /tmp/x270.nix
cat /tmp/out.nix
# project entry (cute `meow.purr` name as requested)
cat meow.toml          # [project] entry = "meow.purr"
cat meow.purr          # import "purr/examples/roles/..." + host x270 (purr-native)
# purr-native orchestration (meow.purr → Nix → System, no generated.nix in repo)
./zig-out/bin/purr rebuild --dry-run   # full pipeline, writes /tmp/purr-x270.nix, shows nixos-rebuild cmd
./zig-out/bin/purr rebuild x270 --dry-run
./zig-out/bin/purr rebuild             # auto host (single), eval + nixos-rebuild switch --flake .#x270 (temp hosts/x270/generated.nix + cleanup)
```

## Layout

```
.
├── meow.toml   # [project] entry = "meow.purr" (default)
├── meow.purr   # project entry (host x270, imports purr/examples/roles/*)
├── purr/
│   ├── flake.nix   # devShell, package, checks.purr-tests (37 tests)
│   ├── build.zig
│   ├── src/        # main, cli, lexer, parser, ast, diagnostics, resolver, semantic, nix, fmt, lint (+microvm)
│   ├── tests/{fixtures,golden,e2e.sh}  # + check --json matrix
│   └── examples/{minimal,bundle,preset,hosts/{x270,mireo},roles/*,let_expr}.purr (mireo has microvm grafana/monerod)
└── hosts/x270/default.nix  # ++ pathExists ./generated.nix (purr-native temp artifact)
```

## Status

`master` `75ce574` → `bced3a6` → `2e3c976` → `purr-meow` → `purr-native` (this branch) — 37 tests + E2E green (check --json contract: `purr`/`purr-check-json` CI). Language: `role`/`host`/`bundle`/`preset`/`package`/`import`/`nix` + `let` + `Expr` (`+ - * / % == != && || < > <= >= ! - ()`), `bundle { programs, packages }`, `preset { flags { path = Expr; } }`, `host { use, preset, package, packages = Expr, let, setting, microvm {mem,cpu,net} }`, `host extends`, `microvm` child of `Host` (Phase 5.1), deterministic Nix (`let ... in {config}` + per-setting `let h in expr` for host-local, `packages` → `systemPackages`, `microvm.vms.*`), `did you mean?` diagnostics, `check --json` (`ok`/`code`/`codeName`/`span` nested, `W004` unused_let, `E060` invalid_microvm), `meow.purr` discovery via `meow.toml` (cwd→parents), `purr rebuild` orchestration (`meow.purr` → AST → resolver → semantic → Nix → `/tmp/purr-<host>.nix` → temp `hosts/<host>/generated.nix` → `nixos-rebuild switch --flake .#<host>` → cleanup, `--dry-run`).

Branch layout (purr-native plan):
- `master` — clean shared base
- `legacy-dev` — existing NixOS/framework + microVMs continue
- `purr-native` — Homelab stepwise to pure Purr (`meow.purr` as source-of-truth, Nix as backend artifact only)

Target is “real language that feels like Lucy code”, not a Nix wrapper — see `docs/purr/design.md`.
