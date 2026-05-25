{...}: {
  imports = [
    ./hardware-configuration.nix
    ./host.nix
    ./monerod-microvm.nix
    ./network-services-microvm.nix
    ./yammat-microvm.nix
  ];
}
