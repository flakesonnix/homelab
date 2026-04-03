#!/usr/bin/env bash
set -e

FLAKE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  echo "Usage: $0 <host> [switch|boot|build]"
  echo "  host: p50, desktop, omen"
  echo "  action: switch (default), boot, build"
  exit 1
}

HOST="${1:-}"
ACTION="${2:-switch}"

if [[ -z "$HOST" ]]; then
  usage
fi

declare -A TARGETS
TARGETS=(
  [p50]="lucy@192.168.178.31"
  [desktop]="lucy@192.168.178.2"
  [omen]="lucy@192.168.178.4"
)

if [[ ! -v "TARGETS[$HOST]" ]]; then
  echo "Unknown host: $HOST"
  usage
fi

case "$ACTION" in
  switch|boot|build)
    ;;
  *)
    echo "Unknown action: $ACTION"
    usage
    ;;
esac

TARGET="${TARGETS[$HOST]}"

echo "Deploying to $HOST ($TARGET)..."
nixos-rebuild "$ACTION" --flake "$FLAKE#$HOST" --target-host "$TARGET" --build-host "$TARGET"
