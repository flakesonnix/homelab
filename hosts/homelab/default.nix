{ config, pkgs, lib, ... }:

{
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.systemd-boot.enable = true;

  fileSystems."/" = {
    device = "/dev/sda1";
    fsType = "ext4";
  };

  networking.hostName = "homelab";
  networking.nameservers = [ "127.0.0.1" ];
  networking.useNetworkd = true;
  networking.firewall.enable = false;

  systemd.network.networks."10-enp8s0" = {
    matchConfig.Name = "enp8s0";
    networkConfig.DHCP = "yes";
  };

  systemd.network.networks."20-enp4s0" = {
    matchConfig.Name = "enp4s0";
    linkConfig.RequiredForOnline = "routable";
  };

  boot.kernel.sysctl = {
    "net.ipv4.conf.all.forwarding" = true;
  };

  networking.interfaces = {
    enp8s0.useDHCP = true;
    enp4s0 = {
      useDHCP = false;
      ipv4.addresses = [{
        address = "10.8.0.1";
        prefixLength = 8;
      }];
    };
  };

  networking.nftables = {
    enable = true;
    ruleset = ''
      table ip filter {
        chain input {
          type filter hook input priority 0; policy drop;
          iifname "enp4s0" accept
          iifname "enp8s0" ct state { established, related } accept
          iifname "enp8s0" icmp type { echo-request, destination-unreachable, time-exceeded } accept
          iifname "enp8s0" counter drop
        }
        chain forward {
          type filter hook forward priority 0; policy drop;
          iifname "enp4s0" oifname "enp8s0" accept
          iifname "enp8s0" oifname "enp4s0" ct state { established, related } accept
        }
      }
      table ip nat {
        chain postrouting {
          type nat hook postrouting priority 100; policy accept;
          oifname "enp8s0" masquerade
        }
      }
    '';
  };

  services.kea.dhcp4 = {
    enable = true;
    settings = {
      valid-lifetime = 4000;
      renew-timer = 1000;
      rebind-timer = 2000;
      interfaces-config = {
        interfaces = [ "enp4s0" ];
      };
      lease-database = {
        type = "memfile";
        persist = true;
        name = "/var/lib/kea/dhcp4.leases";
      };
      subnet4 = [
        {
          id = 1;
          interface = "enp4s0";
          subnet = "10.8.0.0/8";
          pools = [
            {
              pool = "10.8.0.10 - 10.8.255.255";
            }
          ];
          option-data = [
            {
              name = "routers";
              data = "10.8.0.1";
            }
            {
              name = "domain-name-servers";
              data = "127.0.0.1";
            }
          ];
        }
      ];
    };
  };

  services.dnsmasq = {
    enable = true;
    settings = {
      cache-size = 1000;
      server = [ "8.8.8.8" "8.8.4.4" ];
    };
  };

  services.openssh.enable = true;
  services.openssh.settings = {
    PermitRootLogin = "prohibit-password";
    PasswordAuthentication = false;
  };

  environment.systemPackages = with pkgs; [
    htop
    vim
    tcpdump
    pciutils
  ];

  users.users.root = {
    initialPassword = "root";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAT5LcBzQCMfPyq0t29vGjz6UCcTXKZWROmUy82A0lrS lucy@p50"
    ];
  };

  system.stateVersion = "25.05";
}