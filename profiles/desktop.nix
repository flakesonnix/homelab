{ lib, ... }:

{
  imports = [
    ./base.nix
    ../modules/home
  ];

  services.displayManager.gdm.enable = lib.mkDefault true;
  services.desktopManager.gnome.enable = lib.mkDefault true;

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

  programs.home-manager.enable = lib.mkDefault true;
}
