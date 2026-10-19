# Builds a microvm.nix host module from a declarative VM spec.
#
# The spec is checked against a typed submodule (vmSpecType): unknown or
# ill-typed fields abort evaluation instead of being silently ignored.
# Volume entries with `user`/`group` also generate a matching tmpfiles
# ownership rule; `config` is extra VM NixOS config (imports are appended).
spec: {lib, ...}: let
  inherit (lib) mkOption types;
  inherit (import ../../lib/types.nix {inherit lib;}) checked ipv4;

  volumeType = types.submodule {
    options = {
      image = mkOption {type = types.str;};
      mountPoint = mkOption {type = types.path;};
      size = mkOption {type = types.ints.positive;};
      user = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      group = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
    };
  };

  vmSpecType = types.submodule {
    options = {
      name = mkOption {type = types.nonEmptyStr;};
      ip = mkOption {type = ipv4;};
      mem = mkOption {type = types.ints.positive;};
      vcpu = mkOption {type = types.ints.positive;};
      tcpPorts = mkOption {
        type = types.listOf types.port;
        default = [];
      };
      udpPorts = mkOption {
        type = types.listOf types.port;
        default = [];
      };
      volumes = mkOption {
        type = types.listOf volumeType;
        default = [];
      };
      tmpfiles = mkOption {
        type = types.listOf types.str;
        default = [];
      };
      extraDns = mkOption {
        type = types.listOf types.str;
        default = [];
      };
      interfaceId = mkOption {
        type = types.nullOr types.nonEmptyStr;
        default = null;
      };
      shares = mkOption {
        type = types.listOf (types.submodule {
          options = {
            tag = mkOption {type = types.nonEmptyStr;};
            source = mkOption {type = types.nonEmptyStr;};
            mountPoint = mkOption {type = types.nonEmptyStr;};
            readOnly = mkOption {
              type = types.bool;
              default = true;
            };
            proto = mkOption {
              type = types.enum ["virtiofs" "9p"];
              default = "virtiofs";
            };
          };
        });
        default = [];
        description = "Host directories shared into the guest (auto-mounted by microvm.nix at mountPoint).";
      };
      config = mkOption {
        type = types.attrs;
        default = {};
      };
    };
  };

  s = checked vmSpecType spec;
  specConfig = s.config;
  inherit (s) extraDns volumes;
  baseConfig = {
    imports = [
      (import ./microvm-base.nix {
        inherit (s) ip name;
        interfaceId =
          if s.interfaceId == null
          then "vm-${s.name}"
          else s.interfaceId;
        inherit (s) extraDns;
      })
      # Every guest gets the lucy.services.* option tree, so specs can
      # set `lucy.services.<svc>` without importing it per-VM.
      ../../modules/nixos/lucy-services.nix
    ];
    networking.hostName = s.name;
    networking.firewall.allowedTCPPorts = s.tcpPorts;
    networking.firewall.allowedUDPPorts = s.udpPorts;
    microvm.mem = s.mem;
    microvm.vcpu = s.vcpu;
    # Merges (not replaces) microvm-base.nix's ro-store share: module
    # lists concatenate across imports.
    microvm.shares = s.shares;
    microvm.volumes = map (v: lib.removeAttrs v ["user" "group"]) volumes;
    systemd.tmpfiles.rules =
      s.tmpfiles
      ++ lib.concatLists (map (v:
        lib.optionals (v.user != null) [
          "d ${v.mountPoint} 0750 ${v.user} ${v.group} - -"
        ])
      volumes);
  };
in {
  # autostart list is derived by microvm.nix from vms.<name>.autostart
  # Deep merge so spec `config` can extend nested base keys (e.g. adding
  # systemd.services.* must not drop base systemd.tmpfiles.rules).
  # No existing spec overlaps base on nested keys, so this is a no-op
  # for all current VMs (verified: only users.*/services.*/imports used).
  # `imports` still concatenates explicitly (lists would replace).
  microvm.vms.${s.name} = {
    autostart = true;
    config =
      lib.recursiveUpdate baseConfig specConfig
      // lib.optionalAttrs (specConfig ? imports) {
        imports = baseConfig.imports ++ specConfig.imports;
      };
  };
}
