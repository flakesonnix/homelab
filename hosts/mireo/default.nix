{...}: {
  imports = [
    ./hardware-configuration.nix
    ./host.nix
    ./cups-microvm.nix
    ./monerod-microvm.nix
    ./network-services-microvm.nix
    ./sshkeys-microvm.nix
    ./yammat-microvm.nix
  ];
}
