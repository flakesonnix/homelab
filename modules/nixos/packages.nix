{
  lib,
  config,
  pkgs,
  frameworkLib,
  ...
}: let
  projectLib = frameworkLib;
  packageFramework = projectLib.framework.package;
  packageRegistry = import ../../data/packages/system.nix {inherit pkgs;};
in {
  options = with lib; {
    lucy =
      {
        basePackages = mkOption {
          type = types.listOf types.package;
          default = [];
        };
        hostPackages = mkOption {
          type = types.listOf types.package;
          default = [];
        };
      }
      // packageFramework.mkRegistryModule {
        inherit lib;
        registry = packageRegistry;
      };
  };

  config = {
    users.users.lucy.packages =
      config.lucy.basePackages
      ++ config.lucy.hostPackages
      ++ packageFramework.collectTargetPackages {
        enabledAttrs = config.lucy;
        registry = packageRegistry;
        target = "user";
      };

    environment.systemPackages =
      [pkgs.nodejs_22 pkgs.gnome-tweaks]
      ++ packageFramework.collectTargetPackages {
        enabledAttrs = config.lucy;
        registry = packageRegistry;
        target = "system";
      };

    programs.npm.enable = true;
    programs.npm.package = pkgs.nodejs_22;
  };
}
