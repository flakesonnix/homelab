{
  config,
  lib,
  pkgs,
  frameworkLib,
  ...
}: let
  theme = frameworkLib.theme.fromStylix config;
  inherit (theme) colors stripHash;
in {
  config = lib.mkIf config.programs.fuzzel.enable {
    programs.fuzzel = {
      settings = lib.mkForce {
        main = {
          terminal = "alacritty";
          layer = "overlay";
          font = "Inter:size=13";
          icon-theme = "Papirus-Dark";
          width = 52;
          lines = 9;
          horizontal-pad = 24;
          vertical-pad = 18;
          inner-pad = 16;
          prompt = "cyber >  ";
          dpi-aware = "yes";
          show-actions = "yes";
        };
        border = {
          width = 2;
          radius = 22;
        };
        colors = {
          background = "${stripHash colors.base00}ee";
          text = stripHash colors.base05;
          prompt = stripHash colors.base0E;
          placeholder = stripHash colors.base04;
          input = stripHash colors.base07;
          match = stripHash colors.base0C;
          selection = stripHash colors.base0E;
          selection-text = stripHash colors.base00;
          selection-match = stripHash colors.base07;
          counter = stripHash colors.base0A;
          border = stripHash colors.base0E;
        };
      };
    };

    home.packages = [pkgs.inter];
  };
}
