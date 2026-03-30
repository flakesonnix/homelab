{ config, pkgs, lib, ... }:

{
  options.lucy.git = {
    enable = lib.mkEnableOption "lucy's git configuration";
  };

  config = lib.mkIf config.lucy.git.enable {
    programs.git = {
      enable = true;
      settings = {
        user = {
          name = "Lucy";
          email = "lucy@example.com";
        };
        alias = {
          co = "checkout";
          st = "status";
          ci = "commit";
          br = "branch";
          lg = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
        };
      };
    };
  };
}
