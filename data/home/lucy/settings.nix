{
  lib,
  osConfig,
  pkgs,
  ...
}: let
  stylixImage = ../../../home/lucy/wallpapers/omen.jpg;
  wallpaper = "/home/lucy/Pictures/s-l1600.jpg";

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
    # stylix.image needs a store path (build-time color extraction).
    # WALLPAPER is a runtime path for swaybg on niri startup.

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
    stylix.image = stylixImage;
  }

