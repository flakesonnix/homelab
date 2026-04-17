{ lib, config, pkgs, ... }:

{
  options.lucy.hyprland = {
    enable = lib.mkEnableOption "Hyprland compositor configuration";
  };

  config = lib.mkIf config.lucy.hyprland.enable {
    services.xserver.enable = true;
    programs.hyprland.enable = true;
    programs.hyprland.xwayland.enable = true;

    environment.systemPackages = with pkgs; [
      hyprlock
      hypridle
      waybar
      wlogout
      wl-clipboard
      grim
      slurp
      brightnessctl
      playerctl
      networkmanagerapplet
      blueman
    ];

    security.polkit.enable = true;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };
}