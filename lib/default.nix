pkgs: let
  inherit (pkgs) lib;
in {
  # ── Package registry helper ──────────────────────────────────
  mkPackageRegistry = type: import (./. + "/../data/packages/${type}.nix") {inherit pkgs;};

  # ── Domain script libraries ──────────────────────────────────
  waybarScripts = import ./waybar-scripts.nix pkgs;
  systemScripts = import ./system-scripts.nix pkgs;
  audioScripts = import ./audio-scripts.nix pkgs;
  topologyScripts = import ./topology.nix pkgs;
  ciScripts = import ./ci.nix pkgs;
  secretKeys = import ./secret-keys.nix pkgs;

  # ── Sops setup keygen ────────────────────────────────────────
  mkSetupSops = name:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [pkgs.age];
      text = ''
        KEY_DIR=".sops"
        KEY_FILE="$KEY_DIR/keys.txt"
        HOST_NAME="''${1:-omen}"
        if [ -f "$KEY_FILE" ]; then
          echo "Key already exists at $KEY_FILE"
          echo "Delete it and re-run to generate a new one."
          exit 1
        fi
        mkdir -p "$KEY_DIR"
        age-keygen -o "$KEY_FILE"
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
      '';
    };
}
