{ config, pkgs, lib, ... }:

{
  options.lucy.gnomeTheme = {
    enable = lib.mkEnableOption "Pink pastel femboy GNOME theme";
  };

  config = lib.mkIf config.lucy.gnomeTheme.enable {
    gtk = {
      enable = true;
      font = {
        name = "Inter 11";
        package = pkgs.inter;
      };
      iconTheme = {
        name = "Papirus-Dark";
        package = pkgs.papirus-icon-theme;
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

      "org/gnome/desktop/wm/preferences" = {
        button-layout = "appmenu:minimize,maximize,close";
        action-double-click-titlebar = "toggle-maximize";
        action-middle-click-titlebar = "lower";
        action-right-click-titlebar = "menu";
        focus-mode = "click";
        resize-with-right-button = true;
      };

      "org/gnome/desktop/interface" = {
        clock-format = "24h";
        clock-show-weekday = true;
        show-battery-percentage = true;
        enable-animations = true;
      };

      "org/gnome/desktop/peripherals/mouse" = {
        accel-profile = "flat";
      };

      "org/gnome/desktop/peripherals/touchpad" = {
        tap-to-click = true;
        two-finger-scrolling-enabled = true;
      };

      "org/gnome/mutter" = {
        experimental-features = [ "scale-monitor-framebuffer" ];
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
  };
}
