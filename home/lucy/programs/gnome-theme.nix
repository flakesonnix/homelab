{ config, pkgs, lib, ... }:

{
  options.lucy.gnomeTheme = {
    enable = lib.mkEnableOption "Pink pastel femboy GNOME theme";
  };

  config = lib.mkIf config.lucy.gnomeTheme.enable {
    dconf.settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = lib.mkForce "prefer-dark";
        gtk-theme = lib.mkForce "Adwaita-dark";
        icon-theme = lib.mkForce "Papirus-Dark";
        font-name = lib.mkForce "JetBrains Mono 11";
        cursor-size = lib.mkForce 24;
      };

      "org/gnome/desktop/background" = {
        picture-uri = "file:///run/current-system/sw/share/backgrounds/gnome/adwaita-dark.svg";
        picture-uri-dark = "file:///run/current-system/sw/share/backgrounds/gnome/adwaita-dark.svg";
        color-shading-type = "solid";
        primary-color = "#2a1f2d";
      };

      "org/gnome/desktop/screensaver" = {
        picture-uri = "file:///run/current-system/sw/share/backgrounds/gnome/adwaita-dark.svg";
      };

      "org/gnome/shell" = {
        enabled-extensions = [
          "dash-to-dock@micxgx.gmail.com"
          "vicinae@rootmos.github.com"
          "caffeine@patapon.info"
        ];
        theme = "Adwaita-dark";
      };

      "org/gnome/shell/extensions/dash-to-dock" = {
        dock-position = "LEFT";
        show-apps-at-top = true;
        extend-height = false;
        dash-max-icon-size = 48;
        background-color = "#2a1f2d";
        dock-color = "#ff69b4";
        immediate-outline = false;
        shader = "legacy";
      };

      "org/gtk/gtk4/settings/color-chooser" = {
        magenta-hue = 320;
      };

      "org/gnome/settings-daemon/plugins/color" = {
        night-light-enabled = true;
        night-light-temperature = 3500;
      };

      "org/gnome/console" = {
        theme-variant = "dark";
      };
    };

    home.packages = with pkgs; [
      gnomeExtensions.dash-to-dock
      gnomeExtensions.vicinae
      gnomeExtensions.caffeine
      gnomeExtensions.user-themes
    ];
  };
}
