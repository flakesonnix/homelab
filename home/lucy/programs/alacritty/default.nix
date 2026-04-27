{ config, lib, ... }:

{
  options.lucy.alacritty = {
    enable = lib.mkEnableOption "Alacritty configuration";
  };

  config = lib.mkIf config.lucy.alacritty.enable {
    programs.alacritty = {
      enable = true;
      settings = lib.mkForce {
        font = {
          normal = {
            family = "JetBrainsMono Nerd Font";
            style = "Regular";
          };
          bold = {
            family = "JetBrainsMono Nerd Font";
            style = "Bold";
          };
          italic = {
            family = "JetBrainsMono Nerd Font";
            style = "Italic";
          };
          size = 15;
        };

        window = {
          opacity = 0.8;
          blur = true;
          padding = {
            x = 10;
            y = 10;
          };
          dynamic_padding = true;
        };

        scrolling.history = 10000;

        cursor = {
          style = {
            shape = "Block";
            blinking = "On";
          };
          unfocused_hollow = true;
        };
      };
    };
  };
}
