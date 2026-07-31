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
      user = mkOption {type = types.nullOr types.str; default = null;};
      group = mkOption {type = types.nullOr types.str; default = null;};
    };
  };

  vmSpecType = types.submodule {
    options = {
      name = mkOption {type = types.nonEmptyStr;};
      ip = mkOption {type = ipv4;};
      mem = mkOption {type = types.ints.positive;};
      vcpu = mkOption {type = types.ints.positive;};
      tcpPorts = mkOption {type = types.listOf types.port; default = [];};
      udpPorts = mkOption {type = types.listOf types.port; default = [];};
      volumes = mkOption {type = types.listOf volumeType; default = [];};
      tmpfiles = mkOption {type = types.listOf types.str; default = [];};
      extraDns = mkOption {type = types.listOf types.str; default = [];};
      interfaceId = mkOption {type = types.nullOr types.nonEmptyStr; default = null;};
      config = mkOption {type = types.attrs; default = {};};
    };
  };

  s = checked vmSpecType spec;
  specConfig = s.config;
  inherit (s) extraDns volumes;
  baseConfig = {
    imports = [
      (import ./microvm-base.nix {
        inherit (s) ip;
        interfaceId = if s.interfaceId == null then "vm-${s.name}" else s.interfaceId;
        inherit (s) extraDns;
      })
    ];
    networking.hostName = s.name;
    networking.firewall.allowedTCPPorts = s.tcpPorts;
    networking.firewall.allowedUDPPorts = s.udpPorts;
    microvm.mem = s.mem;
    microvm.vcpu = s.vcpu;
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
  microvm.vms.${s.name} = {
    autostart = true;
    config =
      baseConfig
      // specConfig
      // lib.optionalAttrs (specConfig ? imports) {
        imports = baseConfig.imports ++ specConfig.imports;
      };
  };
}
