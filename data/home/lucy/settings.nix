{
  osConfig,
  pkgs,
  ...
}: {
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
