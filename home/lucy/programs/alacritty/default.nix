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
          x = 16;
          y = 16;
        };
        decorations = "full";
        opacity = 0.9;
        dynamic_padding = true;
        blur = true;
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

      cursor.style = {
        shape = "Beam";
        blinking = "On";
      };

      cursor = {
        blink_interval = 450;
        blink_timeout = 0;
        unfocused_hollow = false;
        thickness = 0.22;
      };

      colors = {
        primary = {
          foreground = colors.base05;
          background = colors.base00;
        };
        cursor = {
          text = colors.base00;
          cursor = colors.base0E;
        };
        selection = {
          text = colors.base07;
          background = colors.base03;
        };
        vi_mode_cursor = {
          text = colors.base00;
          cursor = colors.base0C;
        };
        search = {
          matches = {
            foreground = colors.base00;
            background = colors.base0A;
          };
          focused_match = {
            foreground = colors.base00;
            background = colors.base0E;
          };
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
