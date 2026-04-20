{ lib, ... }:

{
  imports = [
    ./base.nix
    ../modules/home
  ];

  services.xserver.enable = lib.mkDefault true;
  services.xserver.xkb = {
    layout = lib.mkDefault "us";
    variant = "";
  };

  services.pipewire = {
    enable = lib.mkDefault true;
    alsa.enable = lib.mkDefault true;
    alsa.support32Bit = true;
    pulse.enable = lib.mkDefault true;
  };
}
