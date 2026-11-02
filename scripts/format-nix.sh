#!/usr/bin/env bash
set -euo pipefail

# Only format versioned source below the current directory. Never traverse
# private keys, untracked build/vendor trees, symlinks or generated hardware.
case "${1:-}" in
  ""|--check) ;;
  --help|-h)
    echo "Usage: format-nix [--check] (tracked Nix source below the current directory)"
    exit 0
    ;;
  *) echo "Usage: format-nix [--check]" >&2; exit 2 ;;
esac
if (( $# > 1 )); then
  echo "Usage: format-nix [--check]" >&2
  exit 2
fi

root=$(git rev-parse --show-toplevel)
mapfile -d '' -t paths < <(git ls-files --cached --deduplicate --full-name -z -- \
  '*.nix' ':(glob,exclude)**/hardware-configuration.nix')
files=()
for path in "${paths[@]}"; do
  if [[ -f "$root/$path" && ! -L "$root/$path" ]]; then
    files+=("$root/$path")
  fi
done

if (( ${#files[@]} > 0 )); then
  nixfmt "$@" "${files[@]}"
fi
