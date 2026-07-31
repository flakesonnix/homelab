{
  config,
  lib,
  pkgs,
  frameworkLib,
  ...
}: let
  colors = config.lib.stylix.colors.withHashtag;
  css = frameworkLib.render.css;
  rules = [
    {
      selector = "terminal";
      declarations = {
        background_color = colors.base00;
        foreground = colors.base05;
        font = ''"JetBrainsMono Nerd Font" 12'';
      };
    }
    {
      selector = "terminal.colors";
      declarations = {
        foreground = colors.base05;
        background = colors.base00;
        color0 = colors.base00;
        color1 = colors.base08;
        color2 = colors.base0B;
        color3 = colors.base0A;
        color4 = colors.base0D;
        color5 = colors.base0E;
        color6 = colors.base0C;
        color7 = colors.base05;
        color8 = colors.base03;
        color9 = colors.base08;
        color10 = colors.base0B;
        color11 = colors.base0A;
        color12 = colors.base0D;
        color13 = colors.base0E;
        color14 = colors.base0C;
        color15 = colors.base07;
      };
    }
  ];
in {
  config = lib.mkIf config.programs.git.enable {
    programs.git = {
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
          lg = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr)%Creset' --abbrev-commit --date=relative";
        };
        core = {
          editor = "nvim";
          pager = "less -FR";
        };
        init = {
          defaultBranch = "main";
        };
        pull = {
          rebase = true;
        };
        url = {
          "https://github.com/" = {
            insteadOf = "gh:";
          };
        };
      };
    };
  };
}
