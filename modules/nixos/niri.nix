{ lib, config, pkgs, inputs, ... }:

{
  options.lucy.niri = {
    enable = lib.mkEnableOption "Niri compositor";
  };

  config = lib.mkIf config.lucy.niri.enable {
    services.xserver.enable = true;
    services.gvfs.enable = true;
    services.udisks2.enable = true;
    programs.niri.enable = true;

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };

    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd ${pkgs.niri}/bin/niri-session";
          user = "greeter";
        };
      };
    };

    environment.systemPackages = with pkgs; [
      wofi
      grim
      slurp
      wl-clipboard
      brightnessctl
      playerctl
      networkmanagerapplet
      blueman
      waybar
      xwayland-satellite
      gvfs
    ];
  };
}
