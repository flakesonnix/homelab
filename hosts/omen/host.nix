{
  lib,
  pkgs,
  wrappers,
  ...
}: let
  projectLib = import ../../lib;
  packageRegistry = import ../../data/packages/system.nix {inherit pkgs;};
  hostData = projectLib.framework.host.loadHostDirectory {
    inherit lib;
    root = ../../data/hosts/omen;
    args = {inherit pkgs wrappers;};
  };
in {
  config = projectLib.framework.host.applyHost {
    inherit lib;
    host = hostData;
    presetRoot = ../../data/presets;
    roleRoot = ../../data/roles;
    inherit packageRegistry;
    packagePath = ["lucy"];
    basePackagePath = ["lucy" "basePackages"];
    systemPackagePath = ["environment" "systemPackages"];
    fontPackagePath = ["fonts" "packages"];
  };
}
