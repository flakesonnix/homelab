{nixos-hardware, ...}: {
  imports = [
    ./hardware-configuration.nix
    ./host.nix
    # Exact 15-dh1xxx profile not in nixos-hardware; keep to generic laptop bits.
    nixos-hardware.nixosModules.common-cpu-intel
    nixos-hardware.nixosModules.common-pc-laptop
    nixos-hardware.nixosModules.common-pc-ssd
  ];
}
