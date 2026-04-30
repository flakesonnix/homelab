{
  lib,
  pkgs,
  wrappers,
  ...
}: let
  projectLib = import ../../lib;
  hostData = import ../../data/hosts/omen {inherit pkgs;};
  presetRegistry = {
    gaming-base = import ../../data/presets/gaming-base.nix;
    gaming-steam = import ../../data/presets/gaming-steam.nix;
  };
  presets = map (name: presetRegistry.${name}) hostData.presets;

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
      inherit presets;
      packagePath = ["lucy"];
      basePackagePath = ["lucy" "basePackages"];
      fontPackagePath = ["fonts" "packages"];
    }
    // {
      hardware.nvidia.powerManagement.enable = lib.mkForce false;

      environment.systemPackages = [hyfetch-wrapped];
    };
}
