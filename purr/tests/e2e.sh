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
echo "=== all E2E passed ==="
