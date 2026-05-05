{
  config,
  lib,
  pkgs,
  frameworkLib,
  ...
}: let
  inherit (frameworkLib.render) css;
  colors = config.lib.stylix.colors.withHashtag;
  rules = [
    {
      selector = "*";
      declarations = {
        bg = "${colors.base00}ee";
        bg_alt = colors.base01;
        fg = colors.base05;
        fg_alt = colors.base04;
        primary = colors.base0D;
        primary_alt = colors.base0C;
        border = colors.base02;
        sep = colors.base02;
        highlight = colors.base0A;
        urgent = colors.base08;
      };
    }
    {
      selector = "window";
      declarations = {
        background_color = "@bg";
        border = "1px";
        border_color = "@border";
        border_radius = "18px";
        padding = "16px";
        box_shadow = "0 8px 32px rgba(0,0,0,0.4)";
      };
    }
    {
      selector = "mainbox";
      declarations = {children = "[inputbar, separator, listview, mode-switcher]";};
    }
    {
      selector = "inputbar";
      declarations = {
        background_color = "@bg-alt";
        border = "1px";
        border_color = "@border";
        border_radius = "12px";
        padding = "10px 14px";
        children = "[prompt, entry]";
      };
    }
    {
      selector = "prompt";
      declarations = {
        background_color = "inherit";
        padding = "0 8px 0 0";
        text_color = "@primary";
        font = ''"Inter 14"'';
      };
    }
    {
      selector = "entry";
      declarations = {
        background_color = "inherit";
        text_color = "@fg";
        font = ''"Inter 14"'';
      };
    }
    {
      selector = "separator";
      declarations = {
        background_color = "@sep";
        margin = "12px 0";
      };
    }
    {
      selector = "listview";
      declarations = {
        background_color = "inherit";
        border = "0px";
        spacing = "6px";
        scrollbar = "true";
        scrollbar_width = "4px";
        scrollbar_color = "@primary";
        scrollbar_border = "false";
        padding = "6px 0";
      };
    }
    {
      selector = "element";
      declarations = {
        background_color = "inherit";
        border = "0px";
        padding = "10px 14px";
        border_radius = "10px";
      };
    }
    {
      selector = "element normal.normal";
      declarations = {
        background_color = "inherit";
        text_color = "@fg";
      };
    }
    {
      selector = "element normal.urgent";
      declarations = {
        background_color = "@urgent";
        text_color = "@bg";
      };
    }
    {
      selector = "element selected.normal";
      declarations = {
        background_color = "@primary";
        text_color = "@bg";
      };
    }
    {
      selector = "element selected.urgent";
      declarations = {
        background_color = "@urgent";
        text_color = "@bg";
      };
    }
    {
      selector = "element-icon";
      declarations = {
        size = "24px";
        background_color = "inherit";
        padding = "0 8px 0 0";
      };
    }
    {
      selector = "element-text";
      declarations = {
        background_color = "inherit";
        text_color = "inherit";
        font = ''"Inter 12"'';
        vertical_align = "0.5";
      };
    }
    {
      selector = "mode-switcher";
      declarations = {
        background_color = "@bg-alt";
        border = "1px";
        border_color = "@border";
        border_radius = "10px";
        padding = "6px";
        spacing = "4px";
      };
    }
    {
      selector = "button";
      declarations = {
        padding = "8px 14px";
        border_radius = "8px";
        background_color = "inherit";
        text_color = "@fg";
      };
    }
    {
      selector = "button selected";
      declarations = {
        background_color = "@primary";
        text_color = "@bg";
      };
    }
    {
      selector = "scrollbar";
      declarations = {
        background_color = "@bg-alt";
        border = "0px";
        handle_color = "@primary";
        handle_width = "4px";
        border_radius = "0px";
      };
    }
  ];
in {
  config = lib.mkIf config.programs.rofi.enable {
    home.packages = [pkgs.rofi];

    xdg.configFile."rofi/config.rasi".text = ''
      configuration {
        modi: "drun,run,window";
        drun-display-format: "{name}";
        show-icons: true;
        icon-theme: "Papirus-Dark";
        drun-icon-theme: "Papirus-Dark";
        font: "Inter 12";
        terminal: "alacritty";
        location: 0;
        yoffset: 0;
        xoffset: 0;
        fixate: false;
        sidebar-mode: false;
        hover-select: false;
        eh: 1;
        auto-select: false;
        sort: true;
        matching: "fuzzy";
        case-sensitive: false;
        cycle: true;
        close-on-select: true;
        close-on-start: false;
        click-to-exit: true;
        drag-margin: 49;
        show-match: true;
        padding: 18;
        separator-style: "solid";
        hide-scrollbar: false;
        fullscreen: false;
        width: 46;
        lines: 8;
        columns: 1;
      }

      @theme "${colors.base00} ${colors.base05} ${colors.base0D} ${colors.base02}"
    '';

    xdg.configFile."rofi/theme.rasi".text = css.renderSheet rules;
  };
}
