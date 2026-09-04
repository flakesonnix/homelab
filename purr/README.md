# Purr — declarative Nix DSL (Zig compiler)

Purr compiles `.purr` → deterministic Nix for NixOS/Home Manager. See `../README.md` (Purr section) and `../docs/purr/design.md` for language design & pipeline.

## Quick start

```bash
nix develop          # zig 0.16 + alejandra
zig build            # builds zig-out/bin/purr + purrc
zig build test       # 13 tests (lexer/parser/semantic/nix + golden)
bash tests/e2e.sh    # E2E: .purr -> Nix -> alejandra + import edge cases

# check / compile
./zig-out/bin/purr check examples/minimal.purr
./zig-out/bin/purr compile examples/minimal.purr --out /tmp/out.nix
./zig-out/bin/purr compile examples/hosts/x270.purr --out /tmp/x270.nix
cat /tmp/out.nix
```

## Layout

```
purr/
├── flake.nix   # devShell, package, checks.purr-tests
├── build.zig
├── src/        # main, cli, lexer, parser, ast, diagnostics, resolver, semantic, nix
├── tests/{fixtures,golden,e2e.sh}
└── examples/{minimal,bundle,preset,hosts/x270,roles/*}.purr
```

## Status

v0.1 on branch `meow` (PR #8) — incremental, 10 commits, 13 tests + E2E green. Language: `role`/`host`/`bundle`/`preset`/`package`/`import`/`nix`, `bundle { programs, packages }`, `preset { flags { path = value; } }`, `host { use, preset, package }`, deterministic Nix, `did you mean?` diagnostics.

No `purr fmt` yet; `purr build` (nix eval) deferred. Target is “real language that feels like Lucy code”, not a Nix wrapper — see `docs/purr/design.md`.
