# Builds a microvm.nix host module from a declarative VM spec.
#
# Spec fields:
#   name, ip, mem, vcpu          required
#   tcpPorts, udpPorts           VM firewall (default [])
#   volumes                      image/mountPoint/size; entries with `user`
#                                and `group` also generate a matching
#                                tmpfiles ownership rule
#   tmpfiles                     extra tmpfiles rules
#   config                       extra VM NixOS config (merged; `imports`
#                                are appended to the base module)
#   extraDns                     extra DNS servers (default [])
spec: {lib, ...}: let
  specConfig = spec.config or {};
  volumes = spec.volumes or [];
  baseConfig = {
    imports = [
      (import ./microvm-base.nix {
        inherit (spec) ip;
        interfaceId = spec.interfaceId or "vm-${spec.name}";
        extraDns = spec.extraDns or [];
      })
    ];
    networking.hostName = spec.name;
    networking.firewall.allowedTCPPorts = spec.tcpPorts or [];
    networking.firewall.allowedUDPPorts = spec.udpPorts or [];
    microvm.mem = spec.mem;
    microvm.vcpu = spec.vcpu;
    microvm.volumes = map (v: lib.removeAttrs v (lib.optionals (v ? user) ["user" "group"])) volumes;
    systemd.tmpfiles.rules =
      (spec.tmpfiles or [])
      ++ lib.concatLists (map (v:
        lib.optionals (v ? user) [
          "d ${v.mountPoint} 0750 ${v.user} ${v.group} - -"
        ])
      volumes);
  };
in {
  # autostart list is derived by microvm.nix from vms.<name>.autostart
  microvm.vms.${spec.name} = {
    autostart = true;
    config =
      baseConfig
      // specConfig
      // lib.optionalAttrs (specConfig ? imports) {
        imports = baseConfig.imports ++ specConfig.imports;
      };
  };
}
