{lib, ...}: let
  projectLib = import ../../../lib;
  bundle = import ../../../data/bundles/dev.nix;
in {
  config = projectLib.framework.bundle.applyBundle {
    inherit lib bundle;
    packagePath = ["lucy" "programs"];
  };
}
