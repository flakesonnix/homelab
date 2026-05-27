{lib, ...}: {
  lucy.base.enable = true;
  lucy.base.isServer = true;
  lucy.base.sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAT5LcBzQCMfPyq0t29vGjz6UCcTXKZWROmUy82A0lrS";
  lucy.base.sshKeyComment = "lucy@mireo";

  networking.hostName = "mireo";
  networking.networkmanager.enable = lib.mkForce false;
  networking.useNetworkd = true;

  systemd.network.enable = true;
  systemd.network.networks."10-wan" = {
    matchConfig.Name = "enp4s0";
    address = ["192.168.178.25/24"];
    routes = [
      {
        Gateway = "192.168.178.1";
      }
    ];
    networkConfig = {
      DNS = ["1.1.1.1" "9.9.9.9"];
      IPv6AcceptRA = false;
    };
  };
  systemd.network.networks."20-lan-enp9s0" = {
    matchConfig.Name = "enp9s0";
    networkConfig.Bridge = "br0";
  };
  systemd.network.networks."21-lan-enp3s0f0" = {
    matchConfig.Name = "enp3s0f0";
    networkConfig.Bridge = "br0";
  };
  systemd.network.networks."22-lan-enp3s0f1" = {
    matchConfig.Name = "enp3s0f1";
    networkConfig.Bridge = "br0";
  };
  systemd.network.netdevs."30-br0" = {
    netdevConfig = {
      Kind = "bridge";
      Name = "br0";
    };
  };
  systemd.network.networks."30-br0" = {
    matchConfig.Name = "br0";
    address = ["10.8.0.1/24"];
    networkConfig = {
      ConfigureWithoutCarrier = true;
      IPv6AcceptRA = false;
      LinkLocalAddressing = "no";
    };
  };

  networking.nat = {
    enable = true;
    externalInterface = "enp4s0";
    internalInterfaces = ["br0"];
  };

  networking.firewall.trustedInterfaces = ["br0"];
  networking.firewall.interfaces.br0.allowedTCPPorts = [19999 9090];

  boot.loader.systemd-boot.enable = true;

  nix.settings.substituters = lib.mkBefore ["http://omen:5000"];
}
