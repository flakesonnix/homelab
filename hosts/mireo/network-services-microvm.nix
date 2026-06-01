{...}: {

  systemd.network.networks."25-lan-microvm" = {
    matchConfig.Name = "vm-net-services";
    networkConfig.Bridge = "br0";
  };

  microvm.autostart = [
    "grafana"
    "network-services"
  ];

  microvm.vms.network-services = {
    autostart = true;
    config = {
      system.stateVersion = "25.11";
      networking.hostName = "network-services";
      networking.firewall.allowedUDPPorts = [53];
      networking.firewall.allowedTCPPorts = [53];

      users.users.root.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAT5LcBzQCMfPyq0t29vGjz6UCcTXKZWROmUy82A0lrS"
      ];
      services.openssh = {
        enable = true;
        settings.PermitRootLogin = "yes";
      };

      microvm = {
        hypervisor = "qemu";
        mem = 384;
        vcpu = 1;
        interfaces = [
          {
            type = "tap";
            id = "vm-net-services";
            mac = "02:00:00:10:08:03";
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
      };

      systemd.network.enable = true;
      systemd.network.networks."20-lan" = {
        matchConfig.Type = "ether";
        address = ["10.8.0.3/24"];
        networkConfig = {
          Gateway = "10.8.0.1";
          DNS = ["10.8.0.1" "1.1.1.1" "9.9.9.9"];
          DHCP = "no";
          IPv6AcceptRA = false;
        };
      };

    };
  };
}
