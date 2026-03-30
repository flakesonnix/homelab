{ lib, config, pkgs, ... }:

{
  options.lucy.home = {
    enable = lib.mkEnableOption "lucy's home-manager configuration";
  };

  config = lib.mkIf (lib.mkDefault false) { };
}
