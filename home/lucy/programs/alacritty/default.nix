{
  config,
  lib,
  ...
}: let
  colors = config.lib.stylix.colors.withHashtag;
in {
  config = lib.mkIf config.programs.alacritty.enable {
    programs.alacritty.settings = {
      env.TERM = "xterm-256color";

      window = {
        padding = {
          x = 12;
          y = 12;
        };
        decorations = "full";
        opacity = 0.8;
      };

      scrolling = {
        history = 10000;
        multiplier = 3;
      };

      font = {
        normal = {
          family = "JetBrainsMono Nerd Font";
          style = "Regular";
        };
        bold = {
          family = "JetBrainsMono Nerd Font";
          style = "Bold";
        };
        size = 13.0;
      };

      colors = {
        primary = {
          foreground = colors.base05;
          background = colors.base00;
        };
        normal = {
          black = colors.base00;
          red = colors.base08;
          green = colors.base0B;
          yellow = colors.base0A;
          blue = colors.base0D;
          magenta = colors.base0E;
          cyan = colors.base0C;
          white = colors.base05;
        };
        bright = {
          black = colors.base03;
          red = colors.base08;
          green = colors.base0B;
          yellow = colors.base0A;
          blue = colors.base0D;
          magenta = colors.base0E;
          cyan = colors.base0C;
          white = colors.base07;
        };
      };
    };
  };
}
