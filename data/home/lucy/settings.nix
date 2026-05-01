{
  osConfig,
  pkgs,
  ...
}: {
  # Keep wallpaper source in one place.
  # Using a Nix path copies it into store (fully declarative), but the file
  # still lives outside repo; move into repo later if you want portability.
  stylix.image = let
    wallpaper = /home/lucy/Pictures/s-l1600.jpg;
  in
    if builtins.pathExists wallpaper
    then wallpaper
    else null;

  stylix.polarity = "dark";

  home.packages = with pkgs; [
    nvd
    nix-tree
  ];

  home.pointerCursor.package = pkgs.callPackage ../../../home/lucy/cursors/default.nix {};

  home.sessionVariables = {
    WALLPAPER = "/home/lucy/Pictures/s-l1600.jpg";
  };

  programs.nh.osFlake = "/home/lucy/Documents/dotfiles#${osConfig.networking.hostName}";
}
