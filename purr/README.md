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
./zig-out/bin/purr check examples/minimal.purr
./zig-out/bin/purr compile examples/minimal.purr --out /tmp/out.nix
./zig-out/bin/purr compile examples/hosts/x270.purr --out /tmp/x270.nix
cat /tmp/out.nix
# project entry (cute `meow.purr` name as requested)
cat meow.toml          # [project] entry = "meow.purr"
cat meow.purr          # import "purr/examples/roles/..." + host meow
```

## Layout

```
.
├── meow.toml   # [project] entry = "meow.purr" (default)
├── meow.purr   # project entry (host meow, imports purr/examples/roles/*)
├── purr/
│   ├── flake.nix   # devShell, package, checks.purr-tests (35 tests)
│   ├── build.zig
│   ├── src/        # main, cli, lexer, parser, ast, diagnostics, resolver, semantic, nix, fmt, lint
│   ├── tests/{fixtures,golden,e2e.sh}  # + check --json matrix
│   └── examples/{minimal,bundle,preset,hosts/x270,roles/*,let_expr}.purr
└── hosts/x270/default.nix  # ++ pathExists ./generated.nix (purr-flake-integration)
```

## Status

`master` `75ce574` → `bced3a6` → `2e3c976` → current `purr-meow` — 35 tests + E2E green (check --json contract: `purr`/`purr-check-json` CI). Language: `role`/`host`/`bundle`/`preset`/`package`/`import`/`nix` + `let` + `Expr` (`+ - * / % == != && || < > <= >= ! - ()`), `bundle { programs, packages }`, `preset { flags { path = Expr; } }`, `host { use, preset, package, packages = Expr, let, setting }`, `host extends`, deterministic Nix (`let ... in {config}` + per-setting `let h in expr` for host-local, `packages` → `systemPackages`), `did you mean?` diagnostics, `check --json` (`ok`/`code`/`codeName`/`span` nested, `W004` unused_let), `meow.purr` discovery via `meow.toml` (cwd→parents).

Target is “real language that feels like Lucy code”, not a Nix wrapper — see `docs/purr/design.md`.
