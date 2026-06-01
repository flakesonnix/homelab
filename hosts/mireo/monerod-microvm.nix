{lib, ...}: {
  networking.nat.forwardPorts = [
    {
      sourcePort = 9001;
      destination = "10.8.0.4:9001";
      proto = "tcp";
    }
  ];

  systemd.network.networks."26-lan-microvm-monerod" = {
    matchConfig.Name = "vm-monerod";
    networkConfig.Bridge = "br0";
  };

  microvm.autostart = ["monerod"];
  microvm.vms.monerod = {
    autostart = true;
    config = {
      imports = [
        (import ./microvm-base.nix {
          ip = "10.8.0.4";
          mac = "02:00:00:10:08:04";
          interfaceId = "vm-monerod";
        })
      ];

      networking.hostName = "monerod";
      networking.firewall.allowedTCPPorts = [22 18080 18081 9001];

      microvm.mem = 2304;
      microvm.vcpu = 2;
      microvm.volumes = [
        {
          image = "monerod-data.img";
          mountPoint = "/var/lib/monero";
          size = 350000;
        }
      ];

      systemd.tmpfiles.rules = [
        "d /var/lib/monero 0750 monero monero - -"
      ];

      services.monero = {
        enable = true;
        dataDir = "/var/lib/monero";
        extraConfig = ''
          rpc-bind-ip=10.8.0.4
          rpc-bind-port=18081
          confirm-external-bind=1
          restricted-rpc=1
          no-igd=1
          prune-blockchain=1
        '';
      };

      services.tor = {
        enable = true;
        relay = {
          enable = true;
          role = "relay";
        };
        settings = {
          Nickname = "mireoMoneroRelay";
          ORPort = 9001;
          ContactInfo = "lucy@local";
          RelayBandwidthRate = "8 Mbits";
          RelayBandwidthBurst = "12 Mbits";
          AccountingMax = "250 GBytes";
        };
      };

      systemd.services.tor.serviceConfig = {
        Nice = 15;
        IOSchedulingClass = "idle";
        CPUWeight = 10;
        IOWeight = 10;
      };

      systemd.services.monero.serviceConfig = {
        Nice = 10;
        IOSchedulingClass = "idle";
        CPUWeight = 25;
        IOWeight = 25;
      };
    };
  };
}
