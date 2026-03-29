{ config, pkgs, lib, ... }:

{
  imports = [
    ./shell.nix
    ./git.nix
    ./editor.nix
    ./packages.nix
  ];

  home = {
    username = "lucy";
    homeDirectory = "/home/lucy";
    stateVersion = "25.11";
  };

  programs.home-manager.enable = true;
}
