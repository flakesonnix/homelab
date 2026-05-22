{nixos-hardware, ...}: {
  imports = [
    ./hardware-configuration.nix
    ./host.nix
    nixos-hardware.nixosModules.lenovo-thinkpad-p50
    nixos-hardware.nixosModules.common-cpu-intel
    nixos-hardware.nixosModules.common-pc-laptop
    nixos-hardware.nixosModules.common-pc-ssd
  ];
}
