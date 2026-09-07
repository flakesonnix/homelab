# Purr (Meow) — Personal Nix DSL — Design & Implementation (Zig)

> Status: **v0.1+** on `master` `75ce574` → `bced3a6` (`check --json` #20) + `2e3c976` (`packages` #21) + `meow.purr` #22. Compiler in Zig 0.16.0 via `nixpkgs#zig`. Language is Purr (`.purr`), design doc originally “Meow” — same project. `purr/` has its own flake (`nix develop` → `zig build`/`zig build test`), 35 tests + `purr/tests/e2e.sh` E2E (`.purr → Nix → alejandra` + `check --json` contract + `meow.purr` discovery). Generated Nix is deterministic (`let` top/per-setting, `packages` → `systemPackages`); `purr check`/`check --json`/`compile`/`fmt`/`lint`/`eval`/`rebuild` work end-to-end (see `purr/README.md`, `meow.purr`).

## 1. Philosophy — What is Meow? Why Nix backend?

**What:** Structured, beginner-friendly infra language that compiles to Nix. Describes desired system, not commands. Personality = Lucy's structured homelab (roles→bundles→presets, data-driven) with playful `meow`/`nya` used intentionally, not spam.

**Why Nix:** Nix is powerful but exposes `lib.mkIf`, `types.submodule`, `overlays` too early. Meow hides that; Nix remains as deterministic, hermetic backend (NixOS/HM evaluation). No shell scripts as primary target.

**Who:** Beginners describing `host/package/service/role` without Nix, plus advanced users via explicit `nix { ... }` escape hatch.

**What it makes easier:** Composing hosts from roles, validating `unknown role`/`duplicate`/`conflicting` early with `did you mean?`, without reading 500p Nix manual.

**Never:** Become generic DSL with cat keywords, or prison — always allow Nix escape, never embed secrets in generated Nix, never hardcode `x270/mireo/Lucy`.

**How Meow differs from Nix/YAML:** Not YAML (has variables, types, imports, composition). Not Nix syntax (no attrsets `//`, no `mkOption`). Own semantic model for infra (`host/role/package` first-class) rather than mirroring Nix.

## 2. Non-goals (v0.1)

- No package registry, marketplace, distributed compiler, IDE/LSP, macro system, custom runtime.
- No functions/modules re-export beyond simple `import`.
- No formatter `meow fmt` yet (AST keeps spans, but formatter deferred until grammar stable).

## 3. Core concepts — first-class vs library

**First-class (language keywords):**
- `host` — machine definition (hostname, roles, packages, services)
- `role` — reusable intent (maps to presets + package tags + bundles, like existing `data/roles/*.nix`)
- `bundle` — HM slice (programs + packageToggles)
- `preset` — host moduleFlags set
- `package` — tagged package entry (library data, but declaration supported)
- `import` — file/module composition
- `nix` — escape hatch block

**Library/framework (not keywords):** `network`, `secret` (integrated via SOPS, not DSL secret literal), `deployment` (future). Keep minimal.

Composition over inheritance: `host x270 { use desktop; use dev; }` rather than `host x270 extends desktop`.

## 4. Syntax — finalized v0.1

**Principles:** Structured, C++-like explicit blocks, readable declarations, declarative. Beginners see `host`/`role`/`package` without `lib.*`. `meow`/`nya` only where meaningful: `meow` = CLI/project name, `nya` = maybe alias for `use`? Decided: keep `use` for clarity, reserve `nya` for future `nya check` diagnostic alias — not keyword spam.

**File extension:** `.purr` (implemented; design said `.meow` — both refer to same DSL). Module naming: file path = module name. Entry: `main.purr` or `meow.toml` (project). v0.1: single file or `import "path.purr"` relative (resolver flattens transitive, `seen` dedup, cycle-safe, `source_map` for diagnostics).

**Proposed syntax (BNF-like):**

```
Program   := Import* Decl*
Import    := 'import' StringLit ';'
Decl      := RoleDecl | HostDecl | BundleDecl | PresetDecl | PackageDecl | NixBlock | LetDecl
LetDecl   := 'let' Ident '=' Expr ';'      // top-level or inside host (lexical, sequential)
RoleDecl  := 'role' Ident '{' RoleField* '}'
RoleField := 'description' '=' StringLit ';'
           | 'targets' '=' List ';'        // ["host","home"]
           | 'requires' '=' List ';'
           | 'conflicts' '=' List ';'
           | 'host' Block
           | 'home' Block
HostDecl  := 'host' Ident ('extends' Ident)? '{' HostStmt* '}'
HostStmt  := 'use' Ident ';'               // role name
           | 'preset' Ident ';'
           | 'package' StringLit ';'       // direct package name
           | 'packages' '=' Expr ';'       // tags, supports let refs: `packages = myPkgs` or `["git", my]`
           | 'setting' Path '=' Expr ';'   // Expr includes binary `base == "x270"`, lists with idents
           | LetDecl
BundleDecl:= 'bundle' Ident '{' ... '}'    // programs, packageToggles
PresetDecl:= 'preset' Ident '{' 'flags' Block '}'
FlagsBlock:= 'flags' '{' (Path '=' Expr ';')* '}'
NixBlock  := 'nix' Block                    // raw Nix for advanced
Block     := '{' (Stmt|Decl)* '}'
List      := '[' (Expr (',' Expr)*)? ']'
Expr      := Primary (BinaryOp Primary)*   // Pratt, prec: || < && < == != < < > <= >= < + - < * / %
Primary   := StringLit | Integer | Boolean | Ident | List | '(' Expr ')' | UnaryOp Primary
Value     := StringLit | Integer | Boolean | List | Ident  // legacy, now Expr
```

**Alternatives considered:**

- A: YAML-like `host: x270:` indented — rejected: not real language, no types, poor diagnostics.
- B: Nix-like `host.x270 = { roles = [ desktop ]; }` — rejected: leaks Nix attrsets.
- C: HCL-like `host "x270" { role = "desktop" }` — okay but less C++ structure.
- Chosen: C++-ish braced blocks + `use` composition, explicit, familiar to Lucy (structured systems), easy recursive-descent.

**Examples:**

Minimal valid:
```meow
// hosts/basic.meow
role desktop {
    description = "Desktop";
    targets = ["host", "home"];
    host {
        presets = ["gaming-base"];
        tags = ["desktop"];
    }
    home {
        bundles = ["desktop"];
    }
}

host x270 {
    use desktop;
    use dev;
    package "git";
    nix {
        // escape: raw Nix for power users
        services.printing.enable = true;
    }
}
```

Realistic infra:
```meow
import "roles/desktop.meow";
import "roles/dev.meow";

host x270 {
    use desktop;
    use dev;
    use gaming;

    packages = ["dev", "network"];
    preset gaming-performance;
}
```

**Punctuation:** `;` terminates statements, `,` separates list items, `=` for assignments, `//` comments, `/* */` block comments.

## 5. Type system — v0.1 minimal

Language-level: `string`, `integer`, `boolean`, `list<T>`, `ident` (reference). Domain types: `host`, `role`, `bundle`, `preset`, `package` — checked semantically (unknown `use gamingg` → error with suggestions). No generics yet. Lists homogeneous inferred.

Future: `map`, `network` address type, `secret` opaque.

## 6. Imports & project model

`import "relative/path.purr";` resolved relative to file, transitive, `seen` dedup, `source_map` for diagnostics. Project (as of `meow.purr` #22):
```
.
├── meow.toml         # [project] entry = "meow.purr" (default)
├── meow.purr         # entry: import "purr/examples/roles/..." + host meow (cute name as requested)
├── purr/
│   ├── meow.purr (alt) / examples/
│   └── hosts/x270.purr (example)
└── hosts/x270/default.nix  # ++ pathExists ./generated.nix (purr-flake-integration #19)
```
`purr check`/`compile` without file arg walks `cwd`→parents for `meow.toml` → `entry` or `meow.purr` fallback (4 levels, `meow.purr` discovery). `meow.toml` minimal:
```toml
[project]
name = "homelab"
entry = "meow.purr"  # default, can be omitted
```

## 7. AST — choices

**Design A: Tagged-union (chosen)**

```zig
// ast.zig
pub const NodeKind = enum { program, role, host, bundle, preset, package, import, nix };
pub const Node = struct {
    kind: NodeKind,
    span: Span,
    data: Data,
    pub const Data = union(NodeKind) {
        program: Program,
        role: Role,
        host: Host,
        // ...
        nix: NixBlock,
    };
};
pub const Program = struct { imports: []Import, decls: []Node };
pub const Host = struct { name: Ident, uses: []Ident, packages: [][]const u8, span: Span };
```

Pros: idiomatic Zig tagged union, pattern matching via `switch`, compact, deterministic, easy traversal, source span per node.

**Design B: Struct hierarchy (inheritance-like)**

Each decl as separate struct with `base: Node` field, virtual table.

Pros: OOP familiar; Cons: pointer indirection, more allocations, less Zig-idiomatic, harder exhaustive switching.

**Decision:** A, with arena allocation, spans retained.

Source-span: `{ file: []const u8, line: u32, col: u32, len: u32 }` per node.

## 8. Pipeline & IR

```
.meow → Lexer → Tokens → Parser → Meow AST → Semantic Analysis → Resolved Model → Nix Generator → .nix → nix eval → NixOS/HM
```

- Lexer → Tokens (with Span). No regex; handwritten scanner.
- Parser → AST (recursive-descent, error recovery for multiple diagnostics).
- Semantic → ResolvedModel (check unknown/duplicate/conflicts, collect role→preset/bundle graph). Parser asks "valid syntax?", semantic asks "does it make sense?".
- Nix Generator → deterministic `.nix` strings (pure function of ResolvedModel).

No extra IR layers unless needed.

## 9. Allocator strategy (Zig)

- Source text owned by caller (readFile), referenced via slices (zero-copy where possible).
- Lexer: no allocation, slices into source + `Span`.
- Parser: single `ArenaAllocator` per compilation (`ast_arena`). All `Node`, `Ident` strings (duplicated from source) allocated there. Lifetime = compilation. `deinit` after `compile()` frees all.
- Semantic: uses same arena or temporary `ArrayList`; resolved model borrows AST slices.
- CLI: `GeneralPurposeAllocator` for process, `Arena` per file.

No scattered `alloc`s; each module takes `Allocator`.

## 10. Lexer spec

Tokens: `ident`, `keyword` (`role`, `host`, `bundle`, `preset`, `package`, `import`, `use`, `nix`, `description`, `targets`...), `string` (double-quoted, escapes), `integer`, `boolean` (`true`/`false`), `l_brace`, `r_brace`, `l_bracket`, `r_bracket`, `equal`, `semicolon`, `comma`, `comment`, `eof`, `invalid`.

Tracks `line/col` per token, `Span`. Malformed string → `invalid` diagnostic.

## 11. Parser — handwritten recursive-descent

`Parser { tokens: []Token, pos: usize, diagnostics: *Diagnostics }`

- `parseProgram() -> Program`
- `parseImport()`, `parseRole()`, `parseHost()`, etc.
- Error recovery: on `;`/`}` sync, continue to report multiple errors.

## 12. Semantic validation

Checks:
- duplicate `host`/`role` names
- unknown `use` (levenshtein suggest)
- unknown `preset`/`bundle`/`package`
- invalid `targets`
- conflicting roles (`conflicts`)
- missing `description` where required

Diagnostics: structured `Diagnostic { severity, code, message, span, help }`, rendered as:
```
meow error[E042]: unknown role `gamign`  --> hosts/x270.meow:7:9  help: did you mean `gaming`?
```

## 13. Nix backend — separate

`nix.zig`: `generate(resolved: ResolvedModel, allocator) -> []const u8` (nix source).

v0.1 generates:
```nix
# generated from x270.meow
{ ... }: {
  flakesonnix.base.enable = true;
  networking.hostName = "x270";
  # role desktop -> presets
}
```

Deterministic, no secrets.

## 14. Security

Secrets via `nix` escape using `sops-nix` templating, not DSL literal. Compiler never emits plaintext secret.

## 15. Formatter — deferred

Formatter operates on AST; comments preserved via attached `leading_comments`. v0.1: keep spans to allow future `meow fmt`.

## 16. CLI

```
purr check [<file>] [--json]    // parse + semantic (+ W004 unused_let via check --json) → human or JSON {file,ok,diagnostics[{severity,code,codeName,message,span{file,line,col,len,start,end},help}]}
purr check                    // no file → meow.toml → meow.purr discovery (cwd→parents)
purr compile [<file>] [--out generated.nix]  // deterministic Nix (let top → `let ... in {config}` + per-setting `let h in expr`, packages → systemPackages)
purr fmt [<file>] [--out]       // idempotent, formatExpr
purr lint [<file>]              // W001 duplicate_import, W002 empty_decl, W003 unformatted, W004 unused_let
purr eval [<file>] [--json]     // compile → /tmp/purr-eval.nix → nix eval --file
purr rebuild [<host>] [--dry-run] // meow.purr → AST → resolver → semantic → Nix (filtered host) → /tmp/purr-<host>.nix → temp hosts/<host>/generated.nix → nixos-rebuild switch --flake .#<host> → cleanup; auto host if single
```

`--json` → stdout exclusively JSON, `stderr` empty, `ok = !hasErrors()` (warnings ok true), `exit 0`/`1`. Human `render` vs `renderJson` share `codeString` table. Distinguish parse/semantic/nix errors.

## 17. Testing

- Lexer: keywords, strings, comments, invalid chars, `let`/`Expr` tokens
- Parser: valid, nested, missing `;`, `}`, Pratt `Expr`, `let` top/host, `packages = Expr`
- Semantic: unknown role/preset/bundle/ident (E042/E043/E044/E003) + suggest, duplicate host/role/let (E010), ordered_scope (forward/self ref), `host_scope` + `W004` unused_let
- Codegen: golden `example.purr → example.nix` (minimal, bundle_preset, let top/host, packages Expr, string escaping) + deterministic
- Integration: `purr/tests/e2e.sh` — `.purr → Nix → alejandra` + import edge (cyclic/duplicate/transitive/missing) + `check --json` contract (ok, E042/E010/E003/W004, stdout JSON, stderr empty, exit 0/1) + `meow.purr` discovery
- CI: `purr` (35 tests) + `purr-check-json` (minimal/E042/E010/E003/W004 + has file/ok/diagnostics)

Fixtures in `purr/tests/fixtures/` + `purr/tests/golden/`.

## 18. v0.1 scope (must) — current

- **Done:** `program`, `import` (transitive, dedup, cycle-safe, `meow.purr` via `meow.toml`), `host` (`use`/`preset`/`package`/`packages = Expr`/`setting = Expr`/`nix` + `let` + `extends`), `role` (`description`/`targets`/`host`{presets,tags}/`home`{bundles}), `bundle` (`description`, `programs`, `packages`/`packageToggles`), `preset` (`description`, `flags { path = Expr; }`), `package "str";`, `nix { raw }` (source slice, nested braces), `string`/`int`/`bool`/`list`/`Expr` (`let`, `ident`, binary `+ - * / % == != && || < > <= >=`, unary `! -`, `()`), `//`/`/* */`, `;`, `meow.purr` discovery, `check --json` (nested `span`, `W004`)
- Lexer/parser/AST/diagnostics(`source_map`, `render`/`renderJson` shared `codeString`, `sortDiagnostics`)/resolver/semantic(duplicate + unknown role/preset/bundle/ident with `did you mean?`, ordered_scope, host_scope, `W004`)/nix deterministic (`let top in {config}` + per-setting `let h in expr`, `packages` → `systemPackages`, string escaping)/fmt (`formatExpr`, idempotent)/lint (`W001`/`W002`/`W003`/`W004`, deterministic)/CLI `check`/`check --json` (meow discovery, stdout JSON, `ok`/`exit 0/1`)/`compile --out`/`fmt`/`lint`/`eval`/`rebuild`/E2E `tests/e2e.sh` (cyclic/duplicate/transitive/missing + `alejandra` + `check --json` contract)
- Deferred: `service`, `types`/`functions`, `map`/`network`/`secret` types, `repl`.

## 19. Real-world validation

One host (`x270`) + one role (`desktop`) + few packages → generate Nix → `nix eval` must succeed. Don't migrate whole homelab.

## 20. Uncertainties

- Should `preset` be keyword or inside `host` block? Chosen inside `role` + `host` `preset` stmt — validate with homelab data.
- List syntax `["a","b"]` vs `a, b` — chose bracket list for explicitness.
- `nix { ... }` raw syntax: should it be `nix` block or `raw`? Chose `nix` for clarity.

## 21. Project structure (Zig)

```
.
├── meow.toml / meow.purr  // project entry (host meow, default)
├── purr/
│   ├── flake.nix           // devShell (zig 0.16) + package + checks.purr-tests (35)
│   ├── build.zig / build.zig.zon  // link_libc for meow discovery
│   ├── src/
│   │   ├── main.zig        // CLI dispatch
│   │   ├── cli.zig         // check/compile/fmt/lint/eval/rebuild + meow discovery + --json + writeStdout
│   │   ├── lexer.zig       // let, Expr tokens
│   │   ├── parser.zig      // let, Expr Pratt, packages = Expr
│   │   ├── ast.zig         // Let, Expr, Setting(Expr), Host(extends, let)
│   │   ├── diagnostics.zig // source_map, render/renderJson (codeString, sortDiagnostics, writeJsonString)
│   │   ├── resolver.zig    // transitive, seen, cycle-safe, host extends
│   │   ├── semantic.zig    // duplicate + unknown (role/preset/bundle/ident) + ordered_scope/host_scope + W004
│   │   ├── nix.zig         // deterministic, let top/per-setting, packages → systemPackages, string escaping
│   │   ├── fmt.zig         // formatExpr, idempotent
│   │   └── lint.zig        // W001/W002/W003/W004 (checkUnusedLets pub)
│   ├── tests/
│   │   ├── fixtures/       // unknown-role, duplicate-host, unknown-bundle/preset, extends/*
│   │   ├── golden/         // minimal, bundle_preset, let (top/host/packages) .purr→.nix
│   │   └── e2e.sh          // .purr→Nix→alejandra + import edge + check --json contract
│   └── examples/
│       ├── minimal.purr, bundle.purr, preset.purr, let_expr.purr
│       └── hosts/x270.purr, roles/{desktop,dev}.purr
└── hosts/x270/default.nix  // ++ pathExists ./generated.nix
```

Adapt if cleaner.

## 22. Zig version & Nix

Zig 0.16.0 via `nixpkgs#zig` pinned by `flake.lock` (`nixpkgs` input). `build.zig` uses `std.Build`. Nix provides `devShells` with `zig`, `nix develop` reproducible. No global Zig dependency.

## 23. Timeline

Stage1 done (this doc) → Stage2 compiler skeleton → Stage3 semantic → Stage4 homelab integration → Stage5 tooling.
