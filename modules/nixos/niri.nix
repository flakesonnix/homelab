{
  lib,
  config,
  pkgs,
  ...
}: {
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
          command = "${pkgs.tuigreet}/bin/tuigreet --time --time-format '%a %d %b  %H:%M' --remember --remember-session --user-menu --asterisks --width 110 --greeting 'Welcome back' --power-shutdown 'systemctl poweroff' --power-reboot 'systemctl reboot' --cmd ${pkgs.niri}/bin/niri-session";
          user = "greeter";
        };
      };
    };

    environment.systemPackages = with pkgs; [
      awww
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
