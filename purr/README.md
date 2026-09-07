# Purr — declarative Nix DSL (Zig compiler)

Purr compiles `.purr` → deterministic Nix for NixOS/Home Manager. See `../README.md` (Purr section) and `../docs/purr/design.md` for language design & pipeline.

## Quick start

```bash
nix develop          # zig 0.16 + alejandra
zig build            # builds zig-out/bin/purr + purrc
zig build test       # 35 tests (lexer/parser/semantic/nix + golden + check --json)
bash tests/e2e.sh    # E2E: .purr -> Nix -> alejandra + import edge cases + check --json

# check / compile (with meow.purr project entry + per-host modules)
./zig-out/bin/purr check meow.purr
./zig-out/bin/purr check --json        # uses meow.toml → meow.purr, stdout JSON
./zig-out/bin/purr check               # auto meow.purr discovery (cwd→parents)
./zig-out/bin/purr check purr/hosts/x270.purr
./zig-out/bin/purr check purr/hosts/mireo.purr
./zig-out/bin/purr compile examples/minimal.purr --out /tmp/out.nix
./zig-out/bin/purr compile purr/hosts/x270.purr --out /tmp/x270.nix
./zig-out/bin/purr compile purr/hosts/mireo.purr --out /tmp/mireo.nix
cat /tmp/out.nix
# project entry (cute `meow.purr` name as requested) + per-host modules (Phase 6)
cat meow.toml          # [project] entry = "meow.purr" + [hosts] x270/mireo = "purr/hosts/*.purr"
cat meow.purr          # import "purr/hosts/x270.purr"; import "purr/hosts/mireo.purr" (aggregator for `purr check`)
cat purr/hosts/x270.purr  # host x270 { use desktop/dev/gaming; ... }
cat purr/hosts/mireo.purr # host mireo { 7 microVMs }
# purr-native orchestration (meow.purr → Nix → System, no generated.nix in repo, per-host entrypoints)
./zig-out/bin/purr rebuild --dry-run   # full pipeline, writes /tmp/purr-x270.nix, shows nixos-rebuild cmd (auto host if single)
./zig-out/bin/purr rebuild x270 --dry-run   # loads purr/hosts/x270.purr via meow.toml [hosts] (29 tok, 3 decls)
./zig-out/bin/purr rebuild mireo --dry-run  # loads purr/hosts/mireo.purr (205 tok, 1 decl, 7 VMs)
./zig-out/bin/purr rebuild             # auto host (single), eval + nixos-rebuild switch --flake .#<host> (temp hosts/<host>/generated.nix + cleanup)
```

## Layout

```
.
├── meow.toml   # [project] entry = "meow.purr" (default) + [hosts] x270/mireo = "purr/hosts/*.purr" (Phase 6)
├── meow.purr   # aggregator: import "purr/hosts/x270.purr"; import "purr/hosts/mireo.purr" (for `purr check` all hosts)
├── purr/
│   ├── hosts/
│   │   ├── x270.purr   # host x270 { use desktop/dev/gaming; packages; preset; }
│   │   └── mireo.purr  # host mireo { 7 microVMs (grafana 768/.2/vol×2, monerod 1024/.4, network-services 256/.3, cups 512/.6/cups-etc, aptcache 512/.8/aptcache, sshkeys 256/.7, yammat 1024/.5) }
│   ├── roles/ {desktop,dev}.purr  # role definitions (used by x270)
│   ├── vms/ (future)   # per-VM modules: grafana.purr, monerod.purr, ... (Phase 6 next)
│   ├── flake.nix   # devShell, package, checks.purr-tests (38 tests)
│   ├── build.zig
│   ├── src/        # main, cli (per-host entrypoints via meow.toml [hosts]), lexer, parser, ast, diagnostics, resolver, semantic, nix, fmt, lint (+microvm ip/volume)
│   ├── tests/{fixtures,golden,e2e.sh}  # + check --json matrix
│   └── examples/{minimal,bundle,preset,hosts/{x270,mireo},roles/*,let_expr}.purr
└── hosts/{x270,mireo}/default.nix  # ++ pathExists ./generated.nix (purr-native temp artifact, mireo cutover done)
```

## Status

`master` `75ce574` → `bced3a6` → `2e3c976` → `purr-meow` → `purr-native` (this branch) — 38 tests + E2E green (check --json contract: `purr`/`purr-check-json` CI). Language: `role`/`host`/`bundle`/`preset`/`package`/`import`/`nix` + `let` + `Expr` (`+ - * / % == != && || < > <= >= ! - ()`), `bundle { programs, packages }`, `preset { flags { path = Expr; } }`, `host { use, preset, package, packages = Expr, let, setting, microvm {mem,cpu,net,ip,volume{image,mountPoint,size}} }`, `host extends`, `microvm` child of `Host` (Phase 5.1/5.2), deterministic Nix (`let ... in {config}` + per-setting `let h in expr` for host-local, `packages` → `systemPackages`, `microvm.vms.*` with ip/volumes), `did you mean?` diagnostics, `check --json` (`ok`/`code`/`codeName`/`span` nested, `W004` unused_let, `E060` invalid_microvm), `meow.purr` discovery via `meow.toml` (cwd→parents) + per-host modules `purr/hosts/<host>.purr` via `[hosts]` (Phase 6), `purr rebuild` per-host entrypoints (`purr/hosts/x270.purr` 29tok vs `purr/hosts/mireo.purr` 205tok, vs `meow.purr` aggregator 230tok) → AST → resolver → semantic → Nix → `/tmp/purr-<host>.nix` → temp `hosts/<host>/generated.nix` → `nixos-rebuild switch --flake .#<host>` → cleanup, `--dry-run`.

Branch layout (purr-native plan):
- `master` — clean shared base
- `legacy-dev` — existing NixOS/framework + microVMs continue
- `purr-native` — Homelab stepwise to pure Purr (`meow.purr` as source-of-truth, Nix as backend artifact only)

Target is “real language that feels like Lucy code”, not a Nix wrapper — see `docs/purr/design.md`.
