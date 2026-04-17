{ lib, config, pkgs, ... }:

{
  options.lucy.router = {
    enable = lib.mkEnableOption "Router configuration with DHCP server";
    interface = lib.mkOption {
      type = lib.types.str;
      description = "Interface for the internal network";
    };
    ipv4Range = lib.mkOption {
      type = lib.types.str;
      default = "10.0.0.128/25";
      description = "DHCPv4 range";
    };
    ipv4Gateway = lib.mkOption {
      type = lib.types.str;
      default = "10.0.0.1";
      description = "IPv4 gateway";
    };
  };

  config = lib.mkIf config.lucy.router.enable {
    services.kea.dhcp4 = {
      enable = true;
      settings = {
        server-tag = "desktop-router";
        interface = [ config.lucy.router.interface ];
        lease-database = {
          type = "memfile";
          persist = true;
          lfc-interval = 3600;
        };
        subnet4 = [
          {
            subnet = "10.0.0.0/8";
            id = 1;
            pools = [
              {
                pool = config.lucy.router.ipv4Range;
              }
            ];
            option-data = [
              {
                name = "routers";
                data = config.lucy.router.ipv4Gateway;
              }
              {
                name = "domain-name-servers";
                data = config.lucy.router.ipv4Gateway;
              }
            ];
          }
        ];
      };
    };

    services.radvd = {
      enable = true;
      config = ''
        interface ${config.lucy.router.interface}
        {
          AdvSendAdvert on;
          AdvManagedFlag on;
          AdvOtherConfigFlag on;
          prefix ::/0
          {
            AdvValidLifetime 7200;
            AdvPreferredLifetime 3600;
          };
        };
      '';
    };

    networking.firewall.trustedInterfaces = [ config.lucy.router.interface ];

    networking.nat = {
      enable = true;
      externalInterface = "wlp2s0";
      internalInterfaces = [ config.lucy.router.interface ];
    };
  };
}