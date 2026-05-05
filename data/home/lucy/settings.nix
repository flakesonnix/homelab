{
  osConfig,
  pkgs,
  ...
}: let
  wallpaper = /home/lucy/Pictures/s-l1600.jpg;
  hasWallpaper = builtins.pathExists wallpaper;
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

    home.pointerCursor = {
      package = pkgs.callPackage ../../../home/lucy/cursors/default.nix {};
      name = "HelloKittyPeachMilkDonut";
      size = 24;
      gtk.enable = true;
      x11.enable = true;
    };

    home.sessionVariables =
      if hasWallpaper
      then {
        WALLPAPER = toString wallpaper;
      }
      else {};

    programs.nh.osFlake = "/home/lucy/Documents/dotfiles#${osConfig.networking.hostName}";
  }
  // (
    if hasWallpaper
    then {
      stylix.image = wallpaper;
    }
    else {}
  )
