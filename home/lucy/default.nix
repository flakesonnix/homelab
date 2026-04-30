{
  lib,
  osConfig,
  pkgs,
  ...
}: let
  projectLib = import ../../lib;
  packageRegistry = import ../../data/packages/home.nix {inherit pkgs;};
  homeData = projectLib.framework.home.loadHomeDirectory {
    inherit lib;
    root = ../../data/home/lucy;
    args = {inherit osConfig pkgs;};
  };
in {
  imports = [
    ./shell.nix
    ./git.nix
    ./editor.nix
    ./programs/alacritty
    ./programs/packages.nix
    ./programs/easyeffects
    ./programs/fuzzel.nix
    ./programs/htop.nix
    ./programs/btop.nix
    ./programs/bat
    ./programs/fzf
    ./programs/firefox.nix
    ./programs/gnome-theme.nix
    ./programs/thunderbird.nix
    ./programs/vesktop.nix
    ./programs/zathura
    ../../modules/home
  ];

  config = projectLib.framework.home.applyHome {
    inherit lib;
    home = homeData;
    roleRoot = ../../data/roles/home;
    bundleRoot = ../../data/bundles;
    inherit packageRegistry;
    packagePath = ["lucy" "programs"];
  };
}
