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
    services.dhcpd = {
      enable = true;
      interfaces = [ config.lucy.router.interface ];
      settings = {
        default-lease-time = 7200;
        max-lease-time = 86400;
        option subnet-mask = "255.0.0.0";
        option routers = config.lucy.router.ipv4Gateway;
        option domain-name-servers = config.lucy.router.ipv4Gateway;
        subnet = config.lucy.router.interface {
          pool {
            range = config.lucy.router.ipv4Range;
          }
        };
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