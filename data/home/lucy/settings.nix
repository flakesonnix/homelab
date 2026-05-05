{
  osConfig,
  pkgs,
  ...
}: let
  wallpaper = /home/lucy/Pictures/s-l1600.jpg;
  hasWallpaper = builtins.pathExists wallpaper;
in
  {
    # Keep wallpaper source in one place.
    # Using a Nix path copies it into store (fully declarative), but the file
    # still lives outside repo; move into repo later if you want portability.

    stylix.polarity = "dark";

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
    else {
      stylix.base16Scheme = "${pkgs."base16-schemes"}/share/themes/catppuccin-mocha.yaml";
    }
  )
