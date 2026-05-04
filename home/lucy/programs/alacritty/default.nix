{
  config,
  lib,
  pkgs,
  frameworkLib,
  ...
}: let
  colors = config.lib.stylix.colors.withHashtag;
in {
  config = lib.mkIf config.programs.alacritty.enable {
    xdg.configFile."alacritty/alacritty.toml".text = ''
      [env]
      TERM = "xterm-256color"

      [window]
      padding.x = 12
      padding.y = 12
      decorations = "full"
      opacity = 0.85
      startup_mode = "maximized"

      [scrolling]
      history = 10000
      multiplier = 3

      [font]
      normal.family = "JetBrainsMono Nerd Font"
      normal.style = "Regular"
      bold.family = "JetBrainsMono Nerd Font"
      bold.style = "Bold"
      size = 13.0
      use_thinbold = true

      [colors.primary]
      foreground = "${colors.base05}"
      background = "${colors.base00}"

      [colors.normal]
      black = "${colors.base00}"
      red = "${colors.base08}"
      green = "${colors.base0B}"
      yellow = "${colors.base0A}"
      blue = "${colors.base0D}"
      magenta = "${colors.base0E}"
      cyan = "${colors.base0C}"
      white = "${colors.base05}"

      [colors.bright]
      black = "${colors.base03}"
      red = "${colors.base08}"
      green = "${colors.base0B}"
      yellow = "${colors.base0A}"
      blue = "${colors.base0D}"
      magenta = "${colors.base0E}"
      cyan = "${colors.base0C}"
      white = "${colors.base07}"
    '';
  };
}
