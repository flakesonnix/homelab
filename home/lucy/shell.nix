{ config, pkgs, lib, ... }:

{
  options.lucy.shell = {
    enable = lib.mkEnableOption "lucy's shell configuration";
  };

  config = lib.mkIf config.lucy.shell.enable {
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      syntaxHighlighting.enable = true;
    };
    home.sessionVariables = {
      SHELL = "${pkgs.zsh}/bin/zsh";
    };
  };
}
