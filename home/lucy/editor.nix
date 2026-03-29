{ config, pkgs, lib, ... }:

{
  options.lucy.editor = {
    enable = lib.mkEnableOption "lucy's editor configuration";
  };

  config = lib.mkIf config.lucy.editor.enable {
    programs.neovim.enable = true;
  };
}
