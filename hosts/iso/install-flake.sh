#!/bin/bash
set -e

FLAKE_URL="${1:-github:yourusername/homelab}"
HOSTNAME="${2:-nixos}"

MOUNT="/mnt"

echo "Installing NixOS from flake: $FLAKE_URL (host: $HOSTNAME)"

mount | grep "$MOUNT" > /dev/null || {
  echo "Error: $MOUNT is not mounted"
  exit 1
}

nixos-install --flake "$FLAKE_URL#$HOSTNAME" --no-root-passwd

echo "Installation complete!"
