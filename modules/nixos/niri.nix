{
  lib,
  config,
  pkgs,
  ...
}: let
  hasHm = lib.hasAttrByPath ["home-manager" "users"] config;
  hmUserNames =
    if hasHm
    then builtins.attrNames (config.home-manager.users or {})
    else [];

  tuigreetCmd = "${pkgs.tuigreet}/bin/tuigreet --time --time-format '%a %d %b  %H:%M' --remember --remember-session --user-menu --asterisks --width 110 --greeting 'Welcome back' --power-shutdown 'systemctl poweroff' --power-reboot 'systemctl reboot' --cmd ${pkgs.niri}/bin/niri-session";
in {
  config = lib.mkIf config.programs.niri.enable {
    services.gvfs.enable = true;
    services.udisks2.enable = true;

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };

    services.greetd = {
      enable = lib.mkDefault true;
      settings.default_session = {
        command = tuigreetCmd;
        user = "greeter";
      };
    };

    # One-flag setup: NixOS compositor + HM config file.
    home-manager.users = lib.mkIf hasHm (lib.mkMerge (
      map (name: {
        ${name}.programs.niri.enable = lib.mkDefault true;
      })
      hmUserNames
    ));
  };
}
