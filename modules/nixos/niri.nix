{ config, lib, pkgs, ... }:

{
  options.lucy.niri = {
    enable = lib.mkEnableOption "niri window manager";
  };

  config = lib.mkIf config.lucy.niri.enable {
    environment.systemPackages = [
      pkgs.niri
    ];

    services.displayManager.sessionPackages = [
      pkgs.niri
    ];

    xdg = {
      autostart.enable = lib.mkDefault true;
      menus.enable = lib.mkDefault true;
      mime.enable = lib.mkDefault true;
      icons.enable = lib.mkDefault true;
    };

    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
      configPackages = [ pkgs.niri ];
    };

    security.polkit.enable = true;

    systemd.user.services.niri-polkit = {
      description = "PolicyKit Authentication Agent for niri";
      wantedBy = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };
    };

    programs.dconf.enable = lib.mkDefault true;
    fonts.enableDefaultPackages = lib.mkDefault true;
  };
}
