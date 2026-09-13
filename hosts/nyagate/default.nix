{nixos-hardware, ...}: {
  imports = [
    ./hardware-configuration.nix
    ./host.nix
  ];
}
