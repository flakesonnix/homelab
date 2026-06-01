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
      system.stateVersion = "25.11";
      networking.hostName = "monerod";
      networking.firewall.allowedTCPPorts = [22 18080 18081 9001];

      users.users.root.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAT5LcBzQCMfPyq0t29vGjz6UCcTXKZWROmUy82A0lrS"
      ];
      services.openssh = {
        enable = true;
        settings.PermitRootLogin = "yes";
      };

      microvm = {
        hypervisor = "qemu";
        mem = 2304;
        vcpu = 2;
        interfaces = [
          {
            type = "tap";
            id = "vm-monerod";
            mac = "02:00:00:10:08:04";
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
            image = "monerod-data.img";
            mountPoint = "/var/lib/monero";
            size = 350000;
          }
        ];
      };

      systemd.network.enable = true;
      systemd.tmpfiles.rules = [
        "d /var/lib/monero 0750 monero monero - -"
      ];
      systemd.network.networks."20-lan" = {
        matchConfig.Type = "ether";
        address = ["10.8.0.4/24"];
        networkConfig = {
          Gateway = "10.8.0.1";
          DNS = ["10.8.0.1"];
          DHCP = "no";
          IPv6AcceptRA = false;
        };
      };

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
