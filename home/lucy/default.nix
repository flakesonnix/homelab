{
  lib,
  osConfig,
  pkgs,
  frameworkLib,
  ...
}: let
  projectLib = frameworkLib;
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
    ./programs/packages.nix
    ./programs/alacritty
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
    ./programs/eww.nix
    ./programs/rofi.nix
    ./programs/easyeffects.nix
    ../../modules/home
    ../../modules/home/dunst.nix
  ];

  config = projectLib.framework.home.applyHome {
    inherit lib;
    home = homeData;
    roleRoot = ../../data/roles;
    bundleRoot = ../../data/bundles;
    inherit packageRegistry;
    packagePath = ["lucy" "programs"];
  };
}
