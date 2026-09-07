{...}: {
  imports = [
    ./hardware-configuration.nix
    ./host.nix
  ] ++ (if builtins.pathExists ./generated.nix then [ ./generated.nix ] else []);

  # All microvm tap interfaces join the LAN bridge.
  systemd.network.networks."24-lan-microvm" = {
    matchConfig.Name = "vm-*";
    networkConfig.Bridge = "br0";
  };
}
