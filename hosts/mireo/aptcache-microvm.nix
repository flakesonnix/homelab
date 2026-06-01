{pkgs, ...}: {
  systemd.network.networks."30-lan-microvm-aptcache" = {
    matchConfig.Name = "vm-aptcache";
    networkConfig.Bridge = "br0";
  };

  microvm.autostart = ["aptcache"];

  microvm.vms.aptcache = {
    autostart = true;
    config = {
      imports = [
        (import ./microvm-base.nix {
          ip = "10.8.0.8";
          mac = "02:00:00:10:08:08";
          interfaceId = "vm-aptcache";
        })
      ];

      networking.hostName = "aptcache";
      networking.firewall.allowedTCPPorts = [22 3142];

      microvm.mem = 512;
      microvm.vcpu = 1;
      microvm.volumes = [
        {
          image = "aptcache-data.img";
          mountPoint = "/var/cache/apt-cacher-ng";
          size = 8192;
        }
      ];

      users.users.apt-cacher-ng = {
        isSystemUser = true;
        group = "apt-cacher-ng";
        home = "/var/cache/apt-cacher-ng";
      };
      users.groups.apt-cacher-ng = {};

      environment.etc."apt-cacher-ng/acng.conf".text = ''
        Port: 3142
        BindAddress: 0.0.0.0
        CacheDir: /var/cache/apt-cacher-ng
        LogDir: /var/log/apt-cacher-ng
        SupportDir: ${pkgs.apt-cacher-ng}/lib/apt-cacher-ng
        use_dyndns: no
        verbose: 0
        maxConcurrentDownloads: 4
        FreshCacheMaxAge: 6
      '';

      systemd.services.apt-cacher-ng = {
        description = "apt-cacher-ng caching proxy";
        wantedBy = ["multi-user.target"];
        after = ["network.target"];
        serviceConfig = {
          ExecStart = "${pkgs.apt-cacher-ng}/sbin/apt-cacher-ng -c /etc/apt-cacher-ng ForeGround=1";
          User = "apt-cacher-ng";
          Group = "apt-cacher-ng";
          Restart = "on-failure";
        };
      };

      systemd.tmpfiles.rules = [
        "d /var/cache/apt-cacher-ng 0750 apt-cacher-ng apt-cacher-ng -"
        "d /var/log/apt-cacher-ng 0750 apt-cacher-ng apt-cacher-ng -"
      ];
    };
  };
}
