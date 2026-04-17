{ lib, config, pkgs, ... }:

{
  options.lucy.hyprland = {
    enable = lib.mkEnableOption "Hyprland compositor configuration";
  };

  config = lib.mkIf config.lucy.hyprland.enable {
    services.xserver.enable = true;
    services.xserver.displayManager.gdm.enable = lib.mkForce false;
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

    services.greetd.enable = true;
    services.greetd.settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd Hyprland";
        user = "greeter";
      };
    };

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };
}