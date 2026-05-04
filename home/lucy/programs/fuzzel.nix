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
      selector = "main";
      declarations = {
        background_color = "${colors.base00}ee";
        text_color = colors.base05;
        border = "1px solid ${colors.base02}";
        border_radius = "22px";
        padding = "18px";
        font = ''"Inter" 13'';
      };
    }
    {
      selector = "prompt";
      declarations = {
        padding = "0 8px 0 0";
        text_color = colors.base0D;
      };
    }
    {
      selector = "entry";
      declarations = {
        padding = "0";
        text_color = colors.base05;
      };
    }
    {
      selector = "item";
      declarations = {
        padding = "10px 14px";
        border_radius = "10px";
      };
    }
    {
      selector = "item selected";
      declarations = {
        background_color = colors.base0D;
        text_color = colors.base00;
      };
    }
    {
      selector = "item urgent";
      declarations = {
        background_color = colors.base08;
        text_color = colors.base00;
      };
    }
    {
      selector = "icon";
      declarations = {
        size = "24px";
        padding = "0 8px 0 0";
      };
    }
    {
      selector = "counter";
      declarations = {
        padding = "0 0 0 8px";
        text_color = colors.base0C;
      };
    }
    {
      selector = "border";
      declarations = {
        background_color = colors.base02;
        radius = "22px";
      };
    }
  ];
in {
  config = lib.mkIf config.programs.fuzzel.enable {
    programs.fuzzel = {
      settings = lib.mkForce {
        main = {
          terminal = "alacritty";
          layer = "overlay";
          font = "Inter:size=13";
          icon-theme = "Papirus-Dark";
          width = 46;
          lines = 8;
          horizontal-pad = 22;
          vertical-pad = 18;
          inner-pad = 16;
          prompt = "search >  ";
          dpi-aware = "yes";
          show-actions = "yes";
        };
        border = {
          width = 1;
          radius = 22;
        };
      };
    };

    xdg.configFile."fuzzel/colors.css".text = css.renderSheet rules;

    home.packages = [pkgs.inter];
  };
}
