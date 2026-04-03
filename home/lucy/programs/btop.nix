{ config, pkgs, lib, ... }:

{
  options.lucy.btop = {
    enable = lib.mkEnableOption "lucy's btop configuration";
  };

  config = lib.mkIf config.lucy.btop.enable {
    programs.btop = {
      enable = true;
    };
  };
}
