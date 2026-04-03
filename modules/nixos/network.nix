{ lib, config, ... }:

{
  options = {
    networking.staticIP = {
      enable = lib.mkEnableOption "Static IP configuration";
      address = lib.mkOption {
        type = lib.types.str;
        description = "Static IP address";
      };
      prefixLength = lib.mkOption {
        type = lib.types.int;
        default = 24;
        description = "Network prefix length";
      };
      gateway = lib.mkOption {
        type = lib.types.str;
        description = "Gateway IP address";
      };
      dns = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "1.1.1.1" "8.8.8.8" ];
        description = "List of DNS server addresses";
      };
      interface = lib.mkOption {
        type = lib.types.str;
        description = "Network interface name";
      };
    };
  };

  config = lib.mkIf config.networking.staticIP.enable {
    networking.networkmanager.enable = lib.mkForce false;
    networking.useDHCP = false;

    networking.enableIPv6 = true;

    networking.interfaces.${config.networking.staticIP.interface}.ipv4.addresses = [
      {
        address = config.networking.staticIP.address;
        prefixLength = config.networking.staticIP.prefixLength;
      }
    ];

    networking.defaultGateway = {
      address = config.networking.staticIP.gateway;
      interface = config.networking.staticIP.interface;
    };

    networking.nameservers = config.networking.staticIP.dns;
  };
}
