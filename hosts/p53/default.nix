{nixos-hardware, ...}: {
  imports = [
    ./hardware-configuration.nix
    ./host.nix
    # Platte pendelt zwischen X270 und P50: beide ThinkPad-Profile laden.
    # Aktuell läuft die Kiste auf dem P50 (i7-6700HQ, Intel + Nouveau).
    nixos-hardware.nixosModules.lenovo-thinkpad-x270
    nixos-hardware.nixosModules.lenovo-thinkpad-p50
  ];
}
