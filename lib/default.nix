pkgs: let
  inherit (pkgs) lib;
  inherit (import ./types.nix {inherit lib;}) checked packageRegistryType;
  servicesLib = import ./services.nix {inherit lib pkgs;};
  identityLib = import ./identity.nix {inherit lib pkgs;};
  networkLib = import ./network.nix {inherit lib pkgs;};
  storageLib = import ./storage.nix {inherit lib pkgs;};
  reconciliationLib = import ./reconciliation.nix {inherit lib pkgs;};
in {
  # ── Package registry helper ──────────────────────────
  # Imports data/packages/<type>.nix and validates it against the typed
  # registry schema; unknown fields or bad types abort evaluation.
  mkPackageRegistry = type: checked packageRegistryType (import (./. + "/../data/packages/${type}.nix") {inherit pkgs;});

  # ── Service helpers ──────────────────────────────────
  inherit
    (servicesLib)
    mkPostgresDatabase
    mkPostgresDatabases
    mkServiceUser
    mkDataDirectory
    mkReverseProxy
    mkFirewallRule
    mkOIDCClient
    mkPrometheusExporter
    mkSopsSecret
    ;

  # ── Identity helpers ─────────────────────────────────
  inherit
    (identityLib)
    mkLDAPService
    mkKeycloakService
    mkKeycloakRealm
    mkKeycloakReconciler
    mkLDAPReconciler
    ;

  # ── Network helpers ──────────────────────────────────
  inherit
    (networkLib)
    mkDNSRecord
    mkDNSZone
    mkAdGuardHome
    mkNetworkDevice
    mkNetworkSite
    mkNetboxReconciler
    mkLibrenmsReconciler
    mkSNMPConfig
    ;

  # ── Storage helpers ──────────────────────────────────
  inherit
    (storageLib)
    mkStorageVolume
    mkStorageShare
    mkDataDirectoryHost
    mkBackupPolicy
    as
    mkBackupPolicyStorage
    mkPostgreSQLBackup
    mkQuota
    ;

  # ── Reconciliation helpers ───────────────────────────
  inherit
    (reconciliationLib)
    mkReconciler
    mkSafeReconciler
    mkDeclarativeService
    mkSyncConfig
    mkStageSecrets
    mkSopsSecretReference
    ;

  # ── Domain script libraries ──────────────────────────
  waybarScripts = import ./waybar-scripts.nix pkgs;
  systemScripts = import ./system-scripts.nix pkgs;
  topologyScripts = import ./topology.nix pkgs;
  ciScripts = import ./ci.nix pkgs;
  secretKeys = import ./secret-keys.nix pkgs;

  # ── Sops setup keygen ────────────────────────────────
  mkSetupSops = name:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [pkgs.age];
      text = ''
        KEY_DIR=".sops"
        KEY_FILE="$KEY_DIR/keys.txt"
        HOST_NAME="''${1:-x270}"
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
