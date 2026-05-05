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
        border_radius = "18px";
        padding = "16px";
        font = ''"Inter" 12'';
      };
    }
    {
      selector = "prompt";
      declarations = {
        text_color = colors.base0D;
        font_weight = "bold";
      };
    }
    {
      selector = "entry";
      declarations = {
        text_color = colors.base05;
      };
    }
    {
      selector = "list";
      declarations = {
        background_color = "inherit";
        padding = "8px";
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
  ];
in {
  config = lib.mkIf config.programs.fuzzel.enable {
    programs.fuzzel = {
      settings = lib.mkForce {
        main = {
          terminal = "wezterm";
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
