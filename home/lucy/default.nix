{osConfig, ...}: {
  imports = [
    ./bundles/core.nix
    ./bundles/desktop.nix
    ./bundles/dev.nix
    ./shell.nix
    ./git.nix
    ./editor.nix
    ./programs/alacritty
    ./programs/packages.nix
    ./programs/easyeffects
    ./programs/fuzzel.nix
    ./programs/htop.nix
    ./programs/btop.nix
    ./programs/bat
    ./programs/fzf
    ./programs/firefox.nix
    ./programs/gnome-theme.nix
    ./programs/thunderbird.nix
    ./programs/vesktop.nix
    ./programs/zathura
    ../../modules/home
  ];

  programs.nh.osFlake = "/home/lucy/Documents/dotfiles#${osConfig.networking.hostName}";
}
