{ config, pkgs, lib, ... }:

{
  imports = [
    ./shell.nix
    ./git.nix
    ./editor.nix
    ./packages.nix
    (import ../modules/home/ssh.nix)
    (import ../modules/home/stylix.nix)
  ];

  lucy.ssh.enable = true;
  lucy.stylix.enable = true;

  home = {
    username = "lucy";
    homeDirectory = "/home/lucy";
    stateVersion = "25.11";
  };

  programs.home-manager.enable = true;

  home.packages = [
    (pkgs.callPackage ./programs/niri {})
  ];
}
