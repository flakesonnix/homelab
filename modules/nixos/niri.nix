{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.lucy.niri;

  hasHm = lib.hasAttrByPath ["home-manager"] config;

  tuigreetCmd = "${pkgs.tuigreet}/bin/tuigreet --time --time-format '%a %d %b  %H:%M' --remember --remember-session --user-menu --asterisks --width 110 --greeting 'Welcome back' --power-shutdown 'systemctl poweroff' --power-reboot 'systemctl reboot' --cmd ${pkgs.niri}/bin/niri-session";
in {
  options.lucy.niri = {
    enable = lib.mkEnableOption "Niri compositor";

    greetd.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable greetd + tuigreet for Niri.";
    };

    home.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Auto-enable Home Manager lucy.niri config when available.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.gvfs.enable = true;
    services.udisks2.enable = true;
    programs.niri.enable = true;

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };

    services.greetd = lib.mkIf cfg.greetd.enable {
      enable = true;
      settings.default_session = {
        command = tuigreetCmd;
        user = "greeter";
      };
    };

    # One-flag setup: NixOS compositor + HM config file.
    home-manager.users.lucy.lucy.niri.enable = lib.mkIf (cfg.home.enable && hasHm) (lib.mkDefault true);
  };
}
