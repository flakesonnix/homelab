{
  config,
  pkgs,
  lib,
  frameworkLib,
  ...
}: let
  projectLib = frameworkLib;
  packageFramework = projectLib.framework.package;
  inherit (import ../../../lib/types.nix {inherit lib;}) checked packageRegistryType;
  packageRegistry = checked packageRegistryType (import ../../../data/packages/home.nix {inherit pkgs;});
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
  };
}
