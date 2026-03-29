{ config, pkgs, lib, ... }:

{
  options.lucy.git = {
    enable = lib.mkEnableOption "lucy's git configuration";
  };

  config = lib.mkIf config.lucy.git.enable {
    programs.git.enable = true;
  };
}
