#!/usr/bin/env bash
# Setup sops-nix for NixOS dotfiles
# Usage: ./setup-sops.sh

set -e

SOPS_DIR="${SOPS_DIR:-$HOME/.sops}"
KEY_FILE="$SOPS_DIR/keys.txt"

echo "Setting up sops-nix secrets..."

# Create sops directory
mkdir -p "$SOPS_DIR"

# Generate age key if not exists
if [ ! -f "$KEY_FILE" ]; then
    echo "Generating age key at $KEY_FILE..."
    age-keygen -o "$KEY_FILE"
    echo "Age key generated!"
else
    echo "Age key already exists at $KEY_FILE"
fi

# Display public key for NixOS config
echo ""
echo "Add this public key to your NixOS config:"
echo ""
age-keygen -y "$KEY_FILE" | head -1
echo ""
echo "Or add to flake.nix inputs as sops NixOS template:"

# Get public key
PUBKEY=$(age-keygen -y "$KEY_FILE" | head -1)
echo ""
echo "In hosts/<host>/secrets.yaml:"
echo "---"
cat << EOF
keys:
  - &default_age $PUBKEY
creation_rules:
  - path_regex: secrets.yaml
    key_groups:
      - age:
          - *default_age
EOF

echo ""
echo "Setup complete!"
echo ""
echo "Next steps:"
echo "1. Add secrets to hosts/<host>/secrets.yaml"
echo "2. Use sops-edit or: SOPS_AGE_KEY_FILE=$KEY_FILE nvim hosts/<host>/secrets.yaml"
echo "3. Rebuild: nixos-rebuild switch --flake .#<host>"
