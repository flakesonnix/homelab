#!/usr/bin/env bash
set -euo pipefail

# Generate sops-nix age key and prepare directory structure.
# The private key is placed in the repo as .sops/keys.txt
# for use with the SOPS_AGE_KEY_FILE env var.

KEY_DIR=".sops"
KEY_FILE="$KEY_DIR/keys.txt"
HOST_NAME="${1:-omen}"

if [ -f "$KEY_FILE" ]; then
  echo "Key already exists at $KEY_FILE"
  echo "Delete it and re-run to generate a new one."
  exit 1
fi

mkdir -p "$KEY_DIR"
age-keygen -o "$KEY_FILE" 2>&1

PUB_KEY=$(grep "public key:" "$KEY_FILE" | awk '{print $NF}')

echo ""
echo "Generated age key pair:"
echo "  Private: $KEY_FILE"
echo "  Public:  $PUB_KEY"
echo ""
echo "Update .sops.yaml with this public key:"
echo "  creation_rules:"
echo "    - path_regex: hosts/.*/secrets.yaml"
echo "      key_groups:"
echo "        - age:"
echo "            - $PUB_KEY"
echo ""
echo "Create encrypted secrets:"
echo "  SOPS_AGE_KEY_FILE=$KEY_FILE sops hosts/$HOST_NAME/secrets.yaml"
echo ""
echo "Place the key on the target host:"
echo "  sudo mkdir -p /etc/sops/age"
echo "  sudo cp $KEY_FILE /etc/sops/age/keys.txt"
echo "  sudo chmod 600 /etc/sops/age/keys.txt"
