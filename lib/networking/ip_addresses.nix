{ config, lib, ... }:

let
  staticIPv4 = {
    "vicuna" = {
      address = "192.168.178.10";
      prefixLength = 24;
    };
    "uakari" = {
      address = "192.168.178.11";
      prefixLength = 24;
    };
    "tapir" = {
      address = "192.168.178.12";
      prefixLength = 24;
    };
  };

  gateway = "192.168.178.1";

  hostname = config.networking.hostName;
  hostCfg = staticIPv4.${hostname} or null;
in
{
  config = lib.mkMerge [
    (lib.mkIf (hostname == "") (throw "networking.hostName must be set"))

    (lib.mkIf (hostname != "" && hostCfg == null) {
      warnings = [
        "No static IPv4 entry found for host '${hostname}' in lib/networking/ip_addresses.nix — networking left unconfigured."
      ];
    })

    (lib.mkIf (hostCfg != null) {
      networking = {
        useDHCP = false;

        interfaces.eth0 = {
          ipv4.addresses = [
            {
              address = hostCfg.address;
              prefixLength = hostCfg.prefixLength;
            }
          ];
          ipv6.addresses = [ ];
          useDHCP = true;
        };

        defaultGateway = {
          address = gateway;
          interface = "eth0";
        };
      };
    })
  ];
}
