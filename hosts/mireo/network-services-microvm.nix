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
      imports = [
        (import ./microvm-base.nix {
          ip = "10.8.0.3";
          mac = "02:00:00:10:08:03";
          interfaceId = "vm-net-services";
          extraDns = ["1.1.1.1" "9.9.9.9"];
        })
      ];

      networking.hostName = "network-services";
      networking.firewall.allowedUDPPorts = [53];
      networking.firewall.allowedTCPPorts = [53];

      microvm.mem = 384;
      microvm.vcpu = 1;
    };
  };
}
