{
  lib,
  pkgs,
  ...
}: let
  projectLib = import ../../../lib;
  bundle = import ../../../data/bundles/core.nix;
in {
  config =
    projectLib.framework.bundle.applyBundle {
      inherit lib bundle;
      packagePath = ["lucy" "programs"];
    }
    // {
      home =
        bundle.home
        // {
          packages = with pkgs; [
            nvd
            nix-tree
          ];
          pointerCursor =
            bundle.home.pointerCursor
            // {
              package = pkgs.callPackage ../cursors/default.nix {};
            };
        };
      inherit (bundle) programs;
      inherit (bundle) nix;
    };
}
