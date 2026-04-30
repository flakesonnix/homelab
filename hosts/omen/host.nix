{
  lib,
  pkgs,
  wrappers,
  ...
}: let
  projectLib = import ../../lib;
  hostData = import ../../data/hosts/omen {
    inherit lib pkgs;
  };

  hyfetch-wrapped = wrappers.lib.wrapPackage {
    inherit pkgs;
    package = pkgs.hyfetch;
    flags = {
      "-p" = "transgender";
    };
  };
in {
  config =
    projectLib.framework.host.applyHost {
      inherit lib;
      host = hostData;
      presetRoot = ../../data/presets;
      packagePath = ["lucy"];
      basePackagePath = ["lucy" "basePackages"];
      fontPackagePath = ["fonts" "packages"];
    }
    // {
      hardware.nvidia.powerManagement.enable = lib.mkForce false;

      environment.systemPackages = [hyfetch-wrapped];
    };
}
