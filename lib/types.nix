# Own data types and helpers shared across the configuration (data model,
# VMs, services).
{ lib }: let
  inherit (lib) mkOption types;
in rec {
  # IPv4 address, e.g. "10.8.0.5".
  ipv4 = types.strMatching "^([0-9]{1,3}\\.){3}[0-9]{1,3}$";

  # Evaluates a raw attrset through a submodule option type: defaults are
  # applied, unknown or ill-typed fields abort evaluation.
  checked = specType: spec: (lib.evalModules {
    modules = [
      {
        options.spec = mkOption {type = specType;};
        config.spec = spec;
      }
    ];
  }).config.spec;

  # A tagged package registry entry (data/packages/*.nix).
  packageEntry = types.submodule {
    options = {
      description = mkOption {type = types.str;};
      targets = mkOption {type = types.listOf (types.enum ["user" "system" "home"]);};
      packages.user = mkOption {type = types.listOf types.package; default = [];};
      packages.system = mkOption {type = types.listOf types.package; default = [];};
      packages.home = mkOption {type = types.listOf types.package; default = [];};
      tags = mkOption {type = types.listOf types.str; default = [];};
    };
  };
  packageRegistryType = types.attrsOf packageEntry;
}
