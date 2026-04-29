{
  lib,
  osConfig,
  ...
}: let
  projectLib = import ../../../lib;
  bundle = import ../../../data/bundles/desktop.nix;
in {
  config =
    projectLib.framework.bundle.applyBundle {
      inherit lib bundle;
      packagePath = ["lucy" "programs"];
    }
    // {
      inherit (bundle) services;
      inherit (bundle) xdg;
      programs.nh.osFlake = "/home/lucy/Documents/dotfiles#${osConfig.networking.hostName}";
    };
}
