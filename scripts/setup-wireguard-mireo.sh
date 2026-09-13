#!/usr/bin/env bash
# Sets up the mireo WireGuard private key in sops WITHOUT exposing it:
# the key is generated locally, written to a 0600 temp file, embedded into
# the YAML without echo, then encrypted in place and shredded. Run this
# YOURSELF — do not paste its output anywhere: it prints only the *public*
# key (safe to share).
#
# Prerequisites:
#   1. Your age private key at .sops/keys.txt (matches .sops.yaml).
#      The assistant must NOT see this file — restore it yourself.
#   2. nix with flakes (for `nix shell`).
#
# Usage: ./scripts/setup-wireguard-mireo.sh
set -euo pipefail

cd "$(dirname "$0")/.."

KEY_FILE=".sops/keys.txt"
SECRETS_FILE="hosts/mireo/secrets.yaml"

if [[ ! -f "$KEY_FILE" ]]; then
  echo "error: $KEY_FILE missing." >&2
  echo "Restore your age private key there first (it must match .sops.yaml)." >&2
  echo "Do NOT generate a new one — the secrets files are encrypted to the existing key." >&2
  exit 1
fi

if [[ ! -f "$SECRETS_FILE" ]]; then
  echo "error: $SECRETS_FILE missing." >&2
  exit 1
fi

TMPDIR_WORK=$(mktemp -d)
trap 'shred -u "$TMPDIR_WORK"/wg-priv 2>/dev/null || true; rm -rf "$TMPDIR_WORK"' EXIT
PRIV="$TMPDIR_WORK/wg-priv"
PUB="$TMPDIR_WORK/wg-pub"

nix shell nixpkgs#wireguard-tools --command bash -c "wg genkey | tee '$PRIV' | wg pubkey > '$PUB'"
chmod 600 "$PRIV" "$PUB"

# Private key via a 0600 temp file only — never on the command line, never
# echoed. (Deliberately NOT `sops set`: its stdout/in-place behavior is
# version-dependent; plain `sops --encrypt` is predictable.)
export SOPS_AGE_KEY_FILE="$KEY_FILE"
umask 077
WG_PRIV=$(tr -d '\n' < "$PRIV")
printf 'wireguard:\n    mireo-private-key: %s\n' "$WG_PRIV" > "$SECRETS_FILE"
unset WG_PRIV
nix shell nixpkgs#sops --command sops --encrypt --in-place "$SECRETS_FILE"

echo ""
echo "Private key stored encrypted in $SECRETS_FILE."
echo ""
echo "mireo WireGuard PUBLIC key (safe to share, needed for the peer side):"
cat "$PUB"
echo ""
echo "Next steps (see docs/secrets.md):"
echo "  1. Put the purrgate public key + endpoint into data/hosts/mireo/settings.nix"
echo "     (peers[0].publicKey / peers[0].endpoint)."
echo "  2. Deploy the age key to mireo: /etc/sops/age/keys.txt (mode 600)."
echo "  3. nix run .#deploy-mireo"
echo "  4. ssh root@10.8.0.1 'systemctl restart wireguard-wg0 && wg show wg0'"
echo ""
echo "Temp key material is shredded on exit."
