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
    wezterm
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
    age
  ];

  systemPackages = [hyfetch-wrapped];

  fontPackages = with pkgs; [
    hack-font
    nerd-fonts.hack
    font-awesome
  ];
}
