{
  lib,
  pkgs,
  wrappers,
  frameworkLib,
  config,
  ...
}: let
  projectLib = frameworkLib;
  packageRegistry = import ../../data/packages/system.nix {inherit pkgs;};
  hostData = projectLib.framework.host.loadHostDirectory {
    inherit lib;
    root = ../../data/hosts/p50;
    args = {inherit pkgs wrappers;};
  };
in {
  config = lib.mkMerge [
    (projectLib.framework.host.applyHost {
      inherit lib;
      host = hostData;
      presetRoot = ../../data/presets;
      roleRoot = ../../data/roles;
      inherit packageRegistry;
      packagePath = ["lucy"];
      basePackagePath = ["lucy" "basePackages"];
      systemPackagePath = ["environment" "systemPackages"];
      fontPackagePath = ["fonts" "packages"];
    })
    {
      hardware.nvidia.package = lib.mkForce config.boot.kernelPackages.nvidiaPackages.legacy_535;
    }
  ];
}
