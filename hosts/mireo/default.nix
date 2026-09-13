{...}: {
  imports = [
    ./hardware-configuration.nix
    ./host.nix
    ./cups-microvm.nix
    ./monerod-microvm.nix
    ./network-services-microvm.nix
    ./aptcache-microvm.nix
    ./sshkeys-microvm.nix
    ./yammat-microvm.nix
  ];

  # All microvm tap interfaces join the LAN bridge.
  systemd.network.networks."24-lan-microvm" = {
    matchConfig.Name = "vm-*";
    networkConfig.Bridge = "br0";
  };
}
