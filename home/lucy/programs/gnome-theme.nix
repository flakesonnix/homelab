{
  config,
  pkgs,
  lib,
  ...
}: let
  colors = config.lib.stylix.colors.withHashtag;
  wallpaperUri =
    if config.stylix.image != null
    then "file://${toString config.stylix.image}"
    else "file:///run/current-system/sw/share/backgrounds/gnome/adwaita-dark.svg";
in {
  options.programs.gnomeTheme.enable = lib.mkEnableOption "Clean macOS dark GNOME theme";

  config = lib.mkIf config.programs.gnomeTheme.enable {
    gtk = {
      enable = true;
      font = {
        name = lib.mkForce "Inter 11";
        package = lib.mkForce pkgs.inter;
      };
      iconTheme = {
        name = lib.mkForce "Papirus-Dark";
        package = lib.mkForce pkgs.papirus-icon-theme;
      };
      gtk3.extraConfig = {
        gtk-application-prefer-dark-theme = 1;
      };
      gtk4.extraConfig = {
        gtk-application-prefer-dark-theme = 1;
      };
    };

    dconf.settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = lib.mkForce "prefer-dark";
        gtk-theme = lib.mkForce "Adwaita-dark";
        icon-theme = lib.mkForce "Papirus-Dark";
        font-name = lib.mkForce "Inter 11";
        document-font-name = lib.mkForce "Inter 11";
        monospace-font-name = lib.mkForce "JetBrainsMono Nerd Font 11";
        accent-color = lib.mkForce "pink";
        cursor-size = lib.mkForce 24;
      };

      "org/gnome/desktop/background" = {
        picture-uri = wallpaperUri;
        picture-uri-dark = wallpaperUri;
        color-shading-type = "solid";
        primary-color = colors.base00;
      };

      "org/gnome/desktop/screensaver" = {
        picture-uri = wallpaperUri;
      };

      "org/gnome/desktop/wm/preferences" = {
        button-layout = "appmenu:minimize,maximize,close";
        action-double-click-titlebar = "toggle-maximize";
        action-middle-click-titlebar = "lower";
        action-right-click-titlebar = "menu";
        focus-mode = "click";
        resize-with-right-button = true;
      };

      "org/gnome/desktop/peripherals/mouse" = {
        accel-profile = "flat";
      };

      "org/gnome/desktop/peripherals/touchpad" = {
        tap-to-click = true;
        two-finger-scrolling-enabled = true;
      };

      "org/gnome/mutter" = {
        experimental-features = ["scale-monitor-framebuffer"];
      };

      "org/gnome/settings-daemon/plugins/power" = {
        sleep-inactive-ac-type = "nothing";
        sleep-inactive-battery-type = "suspend";
      };

      "org/gnome/desktop/notifications" = {
        show-in-lock-screen = false;
      };

      "org/gnome/nautilus/preferences" = {
        default-folder-viewer = "icon-view";
        migrated-gtk-settings = true;
        search-filter-time-type = "last_modified";
        show-delete-permanently = true;
        show-hidden-files = false;
        sort-directories-first = true;
      };

      "org/gnome/settings-daemon/plugins/color" = {
        night-light-enabled = true;
        night-light-temperature = 3500;
      };

      "org/gnome/console" = {
        theme-variant = "dark";
      };
    };
  };
}
