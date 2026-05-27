{
  lib,
  osConfig,
  pkgs,
  ...
}: let
  wallpaper = ../../../home/lucy/wallpapers/omen.jpg;
  isOmen = osConfig.networking.hostName == "omen";
  isP50 = osConfig.networking.hostName == "p50";
  cyberdeckScheme = {
    system = "base16";
    name = "Kuromi Cyberdeck";
    author = "OpenCode";
    variant = "dark";
    palette = {
      base00 = "#16121b";
      base01 = "#22192a";
      base02 = "#342341";
      base03 = "#57386e";
      base04 = "#8d73a8";
      base05 = "#f2ddf5";
      base06 = "#f9f0fb";
      base07 = "#fff7ff";
      base08 = "#ff7bb0";
      base09 = "#ffb86c";
      base0A = "#ff9df2";
      base0B = "#9cf6c8";
      base0C = "#7df9ff";
      base0D = "#c69bff";
      base0E = "#ff7de9";
      base0F = "#6d3a8f";
    };
  };
in
  {
    # Keep wallpaper source in one place.
    # Using a Nix path copies it into store (fully declarative), but the file
    # still lives outside repo; move into repo later if you want portability.

    stylix.polarity = "dark";
    stylix.base16Scheme = cyberdeckScheme;

    home.packages = with pkgs; [
      nvd
      nix-tree
    ];

    home.sessionVariables.WALLPAPER = toString wallpaper;

    programs.nh.osFlake = "/home/lucy/Documents/dotfiles#${osConfig.networking.hostName}";
  }
  // {
    stylix.image = wallpaper;
  }
  // lib.optionalAttrs isOmen {
    # Firefox is more stable on omen via XWayland than native Wayland with the
    # current NVIDIA stack.
    home.sessionVariables.MOZ_ENABLE_WAYLAND = "0";

    programs.waybar.enable = lib.mkForce true;
  }
  // lib.optionalAttrs isP50 {
    # Keep p50 as simple GNOME/media machine, not full omen desktop/dev setup.
    programs.niri.enable = lib.mkForce false;
    programs.waybar.enable = lib.mkForce false;
    programs.eww.enable = lib.mkForce false;
    programs.fuzzel.enable = lib.mkForce false;
    programs.rofi.enable = lib.mkForce false;
    programs.dunst.enable = lib.mkForce false;
    programs.thunderbird.enable = lib.mkForce false;
    programs.vesktop.enable = lib.mkForce false;
    programs.zathura.enable = lib.mkForce false;
    programs.alacritty.enable = lib.mkForce false;
    services.flatpak.enable = lib.mkForce false;
    lucy.programs.android-studio = lib.mkForce false;

    xdg.desktopEntries.youtube = {
      name = "YouTube";
      genericName = "Video";
      comment = "Open YouTube in Firefox";
      exec = "firefox --new-window https://www.youtube.com/";
      terminal = false;
      categories = ["AudioVideo" "Video"];
      icon = "youtube";
    };

    xdg.desktopEntries.youtube-music = {
      name = "YouTube Music";
      genericName = "Music";
      comment = "Open YouTube Music in Firefox";
      exec = "firefox --new-window https://music.youtube.com/";
      terminal = false;
      categories = ["Audio" "Music"];
      icon = "youtube-music";
    };

    xdg.dataFile."icons/hicolor/scalable/apps/youtube.svg".text = ''
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
        <rect width="128" height="128" rx="28" fill="#0f0f12"/>
        <rect x="18" y="32" width="92" height="64" rx="20" fill="#ff0033"/>
        <path d="M54 46 L86 64 L54 82 Z" fill="#ffffff"/>
      </svg>
    '';

    xdg.dataFile."icons/hicolor/scalable/apps/youtube-music.svg".text = ''
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
        <rect width="128" height="128" rx="28" fill="#0f0f12"/>
        <circle cx="64" cy="64" r="38" fill="#ff0033"/>
        <circle cx="64" cy="64" r="25" fill="none" stroke="#ffffff" stroke-width="8"/>
        <path d="M60 52 L80 64 L60 76 Z" fill="#ffffff"/>
      </svg>
    '';

    xdg.configFile."autostart/youtube-music.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Version=1.0
      Name=YouTube Music
      Comment=Open YouTube Music on login
      Exec=sh -lc 'sleep 12; pgrep -x firefox >/dev/null || exec firefox --new-window https://music.youtube.com/'
      Icon=youtube-music
      Terminal=false
      Categories=Audio;Music;
      StartupNotify=false
      X-GNOME-Autostart-enabled=true
      OnlyShowIn=GNOME;
    '';

    dconf.settings."org/gnome/shell" = {
      favorite-apps = [
        "org.mozilla.firefox.desktop"
        "youtube.desktop"
        "youtube-music.desktop"
        "org.gnome.Nautilus.desktop"
        "org.gnome.Console.desktop"
      ];
    };
  }
