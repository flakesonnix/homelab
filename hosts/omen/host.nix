{
  lib,
  pkgs,
  wrappers,
  ...
}: let
  projectLib = import ../../lib;
  hostData = import ../../data/hosts/omen {
    inherit lib pkgs wrappers;
  };
in {
  config = projectLib.framework.host.applyHost {
    inherit lib;
    host = hostData;
    presetRoot = ../../data/presets;
    packagePath = ["lucy"];
    basePackagePath = ["lucy" "basePackages"];
    systemPackagePath = ["environment" "systemPackages"];
    fontPackagePath = ["fonts" "packages"];
  };
}
