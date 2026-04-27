{
  config,
  lib,
  ...
}: {
  options.lucy.alacritty = {
    enable = lib.mkEnableOption "Alacritty configuration";
  };

  config = lib.mkIf config.lucy.alacritty.enable {
    programs.alacritty = {
      enable = true;
      settings = lib.mkForce {
        font = {
          normal = {
            family = "Inter";
            style = "Regular";
          };
          bold = {
            family = "Inter";
            style = "SemiBold";
          };
          italic = {
            family = "Inter";
            style = "Italic";
          };
          size = 13;
        };

        window = {
          opacity = 0.7;
          blur = true;
          padding = {
            x = 12;
            y = 10;
          };
          dynamic_padding = true;
          decorations = "Buttonless";
        };

        scrolling.history = 10000;

        cursor = {
          style = {
            shape = "Block";
            blinking = "On";
          };
          unfocused_hollow = true;
        };

        colors = {
          primary = {
            background = "#11111e";
            foreground = "#c8c8d8";
            dim_foreground = "#9090b0";
          };
          cursor = {
            text = "#11111e";
            cursor = "#c0c0d8";
          };
        };
      };
    };
  };
}
