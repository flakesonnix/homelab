{ lib, config, pkgs, ... }:

{
  options = {
    networking.glasfaser = {
      enable = lib.mkEnableOption "Telekom Glasfaser PPPoE connection";
      interface = lib.mkOption {
        type = lib.types.str;
        default = "enp0s31f6";
        description = "Physical network interface";
      };
      vlanId = lib.mkOption {
        type = lib.types.int;
        default = 7;
        description = "VLAN ID for Glasfaser connection";
      };
      username = lib.mkOption {
        type = lib.types.str;
        description = "PPPoE username from Telekom";
      };
      passwordFile = lib.mkOption {
        type = lib.types.path;
        description = "Path to file containing PPPoE password";
      };
      dns = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "1.1.1.1" "8.8.8.8" ];
        description = "DNS servers";
      };
    };
  };

  config = lib.mkIf config.networking.glasfaser.enable {
    # Disable NetworkManager for the physical interface
    networking.networkmanager.enable = lib.mkForce false;

    # Create VLAN interface
    networking.vlans = {
      ${config.networking.glasfaser.interface}7 = {
        id = config.networking.glasfaser.vlanId;
        interface = config.networking.glasfaser.interface;
      };
    };

    # PPPoE configuration via pppd
    systemd.network-config = [
      {
        Match.Type = "interface";
        Match.Name = "${config.networking.glasfaser.interface}";
        Network = {
          WakeOnLan = "magic";
          DHCP = "no";
        };
      }
      {
        Match.Type = "interface";
        Match.Name = "${config.networking.glasfaser.interface}.${toString config.networking.glasfaser.vlanId}";
        Network = {
          DHCP = "no";
          LinkLocal = "no";
          IPv6AcceptRA = true;
        };
      }
    ];

    # Configure pppd for PPPoE
    services.pppd = {
      enable = true;
      config = ''
        noipdefault
        defaultroute
        replace-default-route
        usepeerdns
        persist
        maxfail 0
        holdoff 5
        hide-password
        noauth
        plugin pppoe.so
        nic-${config.networking.glasfaser.interface}.${toString config.networking.glasfaser.vlanId}
        user ${config.networking.glasfaser.username}
      '';
      secrets = ''
        "${config.networking.glasfaser.username}" * "${builtins.readFile config.networking.glasfaser.passwordFile}"
      '';
    };

    # DNS configuration
    networking.nameservers = config.networking.glasfaser.dns;
  };
}
