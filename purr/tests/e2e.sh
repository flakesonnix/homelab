#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
echo "=== E2E: .purr -> Nix -> alejandra (syntax) ==="
nix shell nixpkgs#zig -c zig build
./zig-out/bin/purr compile tests/golden/minimal.purr -o /tmp/e2e.nix
cat /tmp/e2e.nix
echo "--- alejandra syntax check (should parse) ---"
# alejandra without --check will format and exit 0 if syntax valid
nix shell nixpkgs#alejandra -c alejandra /tmp/e2e.nix > /dev/null && echo "alejandra: parse ok" || (echo "alejandra: syntax fail" && exit 1)
echo "--- nix-instantiate --parse (syntax) ---"
# nix-instantiate --parse should succeed for valid nix (even with free vars, it parses)
# we test via alejandra above, so just check purr check still ok
echo "parse: ok (via alejandra)"
echo "=== import edge cases ==="
./zig-out/bin/purr check tests/fixtures/unknown-role.purr && echo "unexpected pass" && exit 1 || echo "unknown-role: correctly failed (E042)"
./zig-out/bin/purr check tests/fixtures/duplicate-host.purr && echo "unexpected pass" && exit 1 || echo "duplicate-host: correctly failed (E010)"
./zig-out/bin/purr check tests/fixtures/unknown-bundle.purr && echo "unexpected pass" && exit 1 || echo "unknown-bundle: correctly failed (E044)"
./zig-out/bin/purr check tests/fixtures/unknown-preset.purr && echo "unexpected pass" && exit 1 || echo "unknown-preset: correctly failed (E043)"
echo "=== cyclic / duplicate / transitive / missing ==="
mkdir -p /tmp/e2e_cycle
cat > /tmp/e2e_cycle/a.purr <<'EOP'
import "b.purr";
role a { description = "a"; host { presets = ["gaming-base"]; } }
EOP
cat > /tmp/e2e_cycle/b.purr <<'EOP'
import "a.purr";
role b { description = "b"; home { bundles = ["core"]; } }
EOP
cat > /tmp/e2e_cycle/main.purr <<'EOP'
import "a.purr";
host h { use a; use b; }
EOP
./zig-out/bin/purr check /tmp/e2e_cycle/main.purr && echo "cyclic: ok (seen dedup)" || (echo "cyclic: fail" && exit 1)
# transitive
mkdir -p /tmp/e2e_transitive
cat > /tmp/e2e_transitive/c.purr <<'EOP'
role c { description = "c"; }
EOP
cat > /tmp/e2e_transitive/b.purr <<'EOP'
import "c.purr";
role b { description = "b"; }
EOP
cat > /tmp/e2e_transitive/main.purr <<'EOP'
import "b.purr";
host h { use c; use b; }
EOP
./zig-out/bin/purr check /tmp/e2e_transitive/main.purr && echo "transitive: ok" || (echo "transitive: fail" && exit 1)
# missing
cat > /tmp/e2e_missing.purr <<'EOP'
import "nope.purr";
host h { use desktop; }
EOP
./zig-out/bin/purr check /tmp/e2e_missing.purr && echo "missing: unexpected pass" && exit 1 || echo "missing: correctly failed (E003)"
# duplicate import (should warn but not fail)
cat > /tmp/e2e_dup.purr <<'EOP'
import "a.purr";
import "a.purr";
role a { description = "a"; }
host h { use a; }
EOP
mkdir -p /tmp/e2e_dup
cat > /tmp/e2e_dup/a.purr <<'EOP'
role a { description = "a"; }
EOP
cat > /tmp/e2e_dup/main.purr <<'EOP'
import "a.purr";
import "a.purr";
host h { use a; }
EOP
./zig-out/bin/purr check /tmp/e2e_dup/main.purr && echo "duplicate import: ok (warning suppressed)" || (echo "duplicate import: fail" && exit 1)
echo "=== check --json ==="
./zig-out/bin/purr check examples/minimal.purr --json > /tmp/check_min.json
cat /tmp/check_min.json | nix shell nixpkgs#jq -c jq -e '.ok == true and .diagnostics == []' > /dev/null && echo "check --json minimal: ok" || (echo "check --json minimal: fail" && cat /tmp/check_min.json && exit 1)
# error case: unknown role -> E042, ok false, exit 1, stdout JSON, stderr empty
if ./zig-out/bin/purr check tests/fixtures/unknown-role.purr --json > /tmp/check_unknown.json 2> /tmp/check_unknown.stderr; then echo "check --json unknown-role: wrong exit (expected 1)" && exit 1; fi
cat /tmp/check_unknown.json | nix shell nixpkgs#jq -c jq -e '.ok == false and .diagnostics[0].code == "E042" and .diagnostics[0].codeName == "unknown_role"' > /dev/null && echo "check --json unknown-role: ok" || (echo "check --json unknown-role: fail" && cat /tmp/check_unknown.json && exit 1)
test ! -s /tmp/check_unknown.stderr || (echo "check --json unknown-role: stderr not empty" && cat /tmp/check_unknown.stderr && exit 1)
# duplicate host -> E010
if ./zig-out/bin/purr check tests/fixtures/duplicate-host.purr --json > /tmp/check_dup.json 2> /tmp/check_dup.stderr; then echo "check --json duplicate: wrong exit (expected 1)" && exit 1; fi
cat /tmp/check_dup.json | nix shell nixpkgs#jq -c jq -e '.ok == false and .diagnostics[0].code == "E010"' > /dev/null && echo "check --json duplicate: ok" || (echo "check --json duplicate: fail" && cat /tmp/check_dup.json && exit 1)
# unknown ident -> E003
cat > /tmp/check_unknown_ident.purr <<'EOP'
host x270 { s = unknown; }
EOP
if ./zig-out/bin/purr check /tmp/check_unknown_ident.purr --json > /tmp/check_unknown_ident.json 2> /tmp/check_unknown_ident.stderr; then echo "check --json unknown_ident: wrong exit (expected 1)" && exit 1; fi
cat /tmp/check_unknown_ident.json | nix shell nixpkgs#jq -c jq -e '.ok == false and .diagnostics[0].code == "E003"' > /dev/null && echo "check --json unknown_ident: ok" || (echo "check --json unknown_ident: fail" && cat /tmp/check_unknown_ident.json && exit 1)
# unused let -> W004, ok true, exit 0, warning
cat > /tmp/check_unused.purr <<'EOP'
let unused = "x";

host x270 {
    s = "hello";
}
EOP
./zig-out/bin/purr check /tmp/check_unused.purr --json > /tmp/check_unused.json 2> /tmp/check_unused.stderr; test $? -eq 0 || (echo "check --json unused: wrong exit" && exit 1)
cat /tmp/check_unused.json | nix shell nixpkgs#jq -c jq -e '.ok == true and .diagnostics[0].code == "W004" and .diagnostics[0].codeName == "unused_let"' > /dev/null && echo "check --json unused_let: ok" || (echo "check --json unused_let: fail" && cat /tmp/check_unused.json && exit 1)
test ! -s /tmp/check_unused.stderr || (echo "check --json unused: stderr not empty" && cat /tmp/check_unused.stderr && exit 1)
# stdout exclusively JSON: ensure no extra "purr:" lines in stdout
./zig-out/bin/purr check examples/minimal.purr --json > /tmp/check_stdout.json 2> /tmp/check_stdout.stderr
cat /tmp/check_stdout.json | nix shell nixpkgs#jq -c jq -e 'has("file") and has("ok") and has("diagnostics")' > /dev/null && echo "check --json stdout exclusively JSON: ok" || (echo "check --json stdout not pure JSON" && cat /tmp/check_stdout.json && exit 1)
echo "=== all E2E passed ==="
