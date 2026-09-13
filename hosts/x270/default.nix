{nixos-hardware, ...}: {
  imports = [
    ./hardware-configuration.nix
    ./host.nix
    # Dedicated ThinkPad X270 profile: thinkpad common (trackpoint), Intel CPU,
    # SSD, plus i915.enable_psr=0 to fix random freezes.
    nixos-hardware.nixosModules.lenovo-thinkpad-x270
  ];
}
