{
  config,
  lib,
  pkgs,
  frameworkLib,
  ...
}: let
  colors = config.lib.stylix.colors.withHashtag;
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
        width: 52;
        lines: 9;
        columns: 1;
      }

      @theme "theme.rasi"
    '';

    xdg.configFile."rofi/theme.rasi".text = ''
      * {
        bg: ${colors.base00}f0;
        bg-alt: ${colors.base01}f0;
        bg-panel: ${colors.base02}d8;
        fg: ${colors.base05};
        fg-alt: ${colors.base04};
        primary: ${colors.base0E};
        primary-alt: ${colors.base0D};
        neon: ${colors.base0C};
        urgent: ${colors.base08};
        border: ${colors.base03};
        separator: ${colors.base02};
      }

      window {
        background-color: @bg;
        border: 2px;
        border-color: @primary;
        border-radius: 22px;
        padding: 18px;
      }

      mainbox {
        children: [inputbar, separator, listview, mode-switcher];
        spacing: 12px;
      }

      inputbar {
        background-color: @bg-panel;
        border: 1px;
        border-color: @primary-alt;
        border-radius: 16px;
        padding: 12px 16px;
        children: [prompt, entry];
      }

      prompt {
        background-color: inherit;
        text-color: @primary;
        font: "Inter 14";
        padding: 0 10px 0 0;
      }

      entry {
        background-color: inherit;
        text-color: @fg;
        font: "Inter 14";
      }

      separator {
        background-color: @separator;
        margin: 0;
      }

      listview {
        background-color: inherit;
        border: 0;
        spacing: 8px;
        scrollbar: true;
        scrollbar-width: 4px;
        scrollbar-handle-width: 8px;
        padding: 4px 0;
      }

      element {
        background-color: transparent;
        border: 1px;
        border-color: transparent;
        border-radius: 14px;
        padding: 12px 14px;
      }

      element normal.normal {
        background-color: transparent;
        text-color: @fg;
      }

      element selected.normal {
        background-color: ${colors.base0E}cc;
        border-color: @neon;
        text-color: ${colors.base00};
      }

      element normal.urgent,
      element selected.urgent {
        background-color: @urgent;
        text-color: ${colors.base00};
      }

      element-icon {
        background-color: inherit;
        size: 24px;
        padding: 0 10px 0 0;
      }

      element-text {
        background-color: inherit;
        text-color: inherit;
        font: "Inter 12";
        vertical-align: 0.5;
      }

      mode-switcher {
        background-color: @bg-panel;
        border: 1px;
        border-color: @border;
        border-radius: 14px;
        padding: 6px;
        spacing: 6px;
      }

      button {
        border-radius: 10px;
        padding: 8px 14px;
        text-color: @fg;
      }

      button selected {
        background-color: ${colors.base0E}cc;
        text-color: ${colors.base00};
      }

      scrollbar {
        background-color: @bg-alt;
        handle-color: @primary;
        handle-width: 8px;
        border-radius: 999px;
      }
    '';
  };
}
