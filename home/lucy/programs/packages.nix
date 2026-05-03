{
  config,
  pkgs,
  lib,
  frameworkLib,
  ...
}: let
  projectLib = frameworkLib;
  packageFramework = projectLib.framework.package;
  packageRegistry = import ../../../data/packages/home.nix {inherit pkgs;};
in {
  options.lucy.programs = packageFramework.mkRegistryModule {
    inherit lib;
    registry = packageRegistry;
  };

  config = {
    home.packages = packageFramework.collectTargetPackages {
      enabledAttrs = config.lucy.programs;
      registry = packageRegistry;
      target = "home";
    };

    home.sessionVariables = {
      WALLPAPER = "/home/lucy/Pictures/s-l1600.jpg";
    };
  };
}
