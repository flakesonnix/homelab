{
  pkgs,
  wrappers,
  ...
}: let
  hyfetch-wrapped = wrappers.lib.wrapPackage {
    inherit pkgs;
    package = pkgs.hyfetch;
    flags = {
      "-p" = "transgender";
    };
  };
in {
  basePackages = with pkgs; [
    alacritty
    zathura
    fzf
    bat
    vesktop
    vlc
    p7zip
    thunderbird
    deskflow
    keepassxc
    nodejs_22
    ausweisapp
    kdePackages.kdenlive
    ani-cli
    scdl
  ];

  systemPackages = [hyfetch-wrapped];

  fontPackages = with pkgs; [
    hack-font
  ];
}
