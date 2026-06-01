{lib, pkgs, ...}: let
  keys = import ../../ssh-public-keys.nix {inherit lib;};
in {
  networking.hosts."10.8.0.8" = ["aptcache" "aptcache-vm"];

  systemd.network.networks."30-lan-microvm-aptcache" = {
    matchConfig.Name = "vm-aptcache";
    networkConfig.Bridge = "br0";
  };

  microvm.autostart = ["aptcache"];

  microvm.vms.aptcache = {
    autostart = true;
    config = {
      system.stateVersion = "25.11";
      networking.hostName = "aptcache";
      networking.firewall.allowedTCPPorts = [22 3142];

      users.users.root.openssh.authorizedKeys.keys = [keys.lucy.servers];
      services.openssh = {
        enable = true;
        settings.PermitRootLogin = "yes";
      };

      services.apt-cacher-ng = {
        enable = true;
        extraConfig = ''
          Port: 3142
          BindAddress: 0.0.0.0
          CacheDir: /var/cache/apt-cacher-ng
          LogDir: /var/log/apt-cacher-ng
          SupportDir: /usr/share/apt-cacher-ng
          use_dyndns: no
          verbose: 0
          maxConcurrentDownloads: 4
          FreshCacheMaxAge: 6
        '';
      };

      systemd.tmpfiles.rules = [
        "d /var/cache/apt-cacher-ng 0750 apt-cacher-ng apt-cacher-ng -"
      ];

      microvm = {
        hypervisor = "qemu";
        mem = 512;
        vcpu = 1;
        interfaces = [
          {
            type = "tap";
            id = "vm-aptcache";
            mac = "02:00:00:10:08:08";
          }
        ];
        shares = [
          {
            proto = "virtiofs";
            tag = "ro-store";
            source = "/nix/store";
            mountPoint = "/nix/.ro-store";
          }
        ];
        volumes = [
          {
            image = "aptcache-data.img";
            mountPoint = "/var/cache/apt-cacher-ng";
            size = 8192;
          }
        ];
      };

      systemd.network.enable = true;
      systemd.network.networks."20-lan" = {
        matchConfig.Type = "ether";
        address = ["10.8.0.8/24"];
        networkConfig = {
          Gateway = "10.8.0.1";
          DNS = ["10.8.0.1"];
          DHCP = "no";
          IPv6AcceptRA = false;
        };
      };
    };
  };
}
