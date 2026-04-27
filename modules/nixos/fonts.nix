{ lib, config, pkgs, ... }:

{
  options = {
    lucy.fonts = {
      inter = lib.mkEnableOption "Inter font";
    };
  };

  config = lib.mkIf config.lucy.fonts.inter {
    fonts.packages = [ pkgs.inter ];
  };
}