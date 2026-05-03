{
  lib,
  config,
  pkgs,
  ...
}: let
  hasHm = lib.hasAttrByPath ["home-manager"] config;
  hmUserNames =
    if hasHm
    then builtins.attrNames (config.home-manager.users or {})
    else [];

  configuredUsers = lib.unique config.niri.users;
  invalidUsers = builtins.filter (name: !(builtins.elem name hmUserNames)) configuredUsers;

  tuigreetCmd = "${pkgs.tuigreet}/bin/tuigreet --time --time-format '%a %d %b  %H:%M' --remember --remember-session --user-menu --asterisks --width 110 --greeting 'Welcome back' --power-shutdown 'systemctl poweroff' --power-reboot 'systemctl reboot' --cmd ${pkgs.niri}/bin/niri-session";
in {
  options.niri.users = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
    example = ["lucy"];
    description = "Home Manager users that should receive Niri host integration.";
  };

  config = lib.mkMerge [
    {
      assertions =
        lib.optional (configuredUsers != [] && !hasHm) {
          assertion = false;
          message = "niri.users requires home-manager to be imported.";
        }
        ++ lib.optional (invalidUsers != []) {
          assertion = false;
          message = "niri.users contains unknown Home Manager users: ${builtins.concatStringsSep ", " invalidUsers}";
        };
    }

    (lib.mkIf (configuredUsers != []) {
      programs.niri.enable = lib.mkDefault true;
    })

    (lib.mkIf config.programs.niri.enable {
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

      home-manager.users = lib.mkIf (hasHm && configuredUsers != []) (
        lib.mkMerge (
          map (name: {
            ${name}.programs.niri.enable = lib.mkDefault true;
          })
          configuredUsers
        )
      );
    })
  ];
}
