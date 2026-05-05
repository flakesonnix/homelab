{
  config,
  lib,
  pkgs,
  ...
}: let
  colors = config.lib.stylix.colors.withHashtag;
in {
  config.programs.wezterm = {
    enable = true;
    package = pkgs.wezterm;
  };

  config.xdg.configFile."wezterm/wezterm.lua".text = ''
    local wezterm = require 'wezterm'
    local config = {}

    config.color_scheme = 'Catppuccin Mocha'
    config.font = wezterm.font 'JetBrainsMono Nerd Font', { weight = 'Regular' }
    config.font_size = 13.0
    config.line_height = 1.0

    config.window_padding = {
      left = 12,
      right = 12,
      top = 12,
      bottom = 12,
    }

    config.window_decorations = "RESIZE"
    config.window_background_opacity = 0.85
    config.text_background_opacity = 0.85

    config.enable_tab_bar = false
    config.hide_tab_bar_if_only_one_tab = true

    config.colors = {
      foreground = '${colors.base05}',
      background = '${colors.base00}',
      cursor_bg = '${colors.base05}',
      cursor_border = '${colors.base05}',
      selection_bg = '${colors.base02}',
      ansi = {
        '${colors.base00}',
        '${colors.base08}',
        '${colors.base0B}',
        '${colors.base0A}',
        '${colors.base0D}',
        '${colors.base0E}',
        '${colors.base0C}',
        '${colors.base05}',
      },
      brights = {
        '${colors.base03}',
        '${colors.base08}',
        '${colors.base0B}',
        '${colors.base0A}',
        '${colors.base0D}',
        '${colors.base0E}',
        '${colors.base0C}',
        '${colors.base07}',
      },
    }

    config.keys = {
      { key = 'c', mods = 'CTRL|SHIFT', action = wezterm.action.CopyTo 'Clipboard' },
      { key = 'v', mods = 'CTRL|SHIFT', action = wezterm.action.PasteFrom 'Clipboard' },
      { key = 't', mods = 'CTRL|SHIFT', action = wezterm.action.SpawnTab 'CurrentPaneDomain' },
      { key = 'w', mods = 'CTRL|SHIFT', action = wezterm.action.CloseCurrentTab { confirm = true } },
      { key = 'Tab', mods = 'CTRL', action = wezterm.action.ActivateTabRelative(1) },
    }

    return config
  '';
}